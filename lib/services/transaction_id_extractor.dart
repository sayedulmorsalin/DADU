import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class _TrxCandidate {
  final String id;
  final double yPosition;
  final int confidenceScore;
  final bool isKeywordMatched;

  _TrxCandidate({
    required this.id,
    required this.yPosition,
    required this.confidenceScore,
    required this.isKeywordMatched,
  });
}

/// Service for recognizing text from images and extracting Transaction IDs (TrxID / Txn ID).
class TransactionIdExtractor {
  static TextRecognizer? _recognizer;

  static TextRecognizer get _instance {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  static final RegExp _sameLineRegex = RegExp(
    r'(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি|ট্রানজেকশন\s*নং|লেনদেন\s*আইডি)\s*[:：\-_=\s#]\s*([A-Za-z0-9]{8,18})',
    caseSensitive: false,
  );

  static final RegExp _keywordHeaderRegex = RegExp(
    r'^(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি|ট্রানজেকশন\s*নং|লেনদেন\s*আইডি)[:：\-_=\s#]*$',
    caseSensitive: false,
  );

  static final RegExp _trxTokenRegex = RegExp(
    r'\b([A-Za-z0-9]{8,18})\b',
  );

  /// Scans an image file from [imagePath] and extracts the Transaction ID.
  /// Uses spatial alignment, keyword proximity, and confidence scoring.
  static Future<String?> extractTransactionId(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('[TransactionIdExtractor] File does not exist: $imagePath');
        return null;
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _instance.processImage(inputImage);

      // Collect all lines across blocks with their spatial information
      final List<TextLine> textLines = [];
      for (final block in recognizedText.blocks) {
        textLines.addAll(block.lines);
      }

      if (textLines.isNotEmpty) {
        // Sort lines from top to bottom by Y-coordinate
        textLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

        final List<_TrxCandidate> candidates = [];

        // Check within each block first (preserves column and tile grouping)
        for (final block in recognizedText.blocks) {
          final blockLines = block.lines;
          for (int bi = 0; bi < blockLines.length; bi++) {
            final bText = blockLines[bi].text.trim();
            if (_keywordHeaderRegex.hasMatch(bText) || _containsKeyword(bText)) {
              for (int bj = bi + 1; bj < blockLines.length && bj <= bi + 2; bj++) {
                final targetLine = blockLines[bj];
                final targetText = targetLine.text.trim();
                if (_isAmountOrBalance(targetText)) continue;

                final tokenMatch = _trxTokenRegex.firstMatch(targetText);
                if (tokenMatch != null) {
                  final id = _cleanId(tokenMatch.group(1)!);
                  if (_isValidCandidate(id, isKeywordMatched: true)) {
                    candidates.add(_TrxCandidate(
                      id: id,
                      yPosition: targetLine.boundingBox.bottom.toDouble(),
                      confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
                      isKeywordMatched: true,
                    ));
                    break;
                  }
                }
              }
            }
          }
        }

        // Global line iteration
        for (int i = 0; i < textLines.length; i++) {
          final line = textLines[i];
          final text = line.text.trim();
          final yPos = line.boundingBox.bottom.toDouble();

          // 1. Same line keyword match (e.g. "TrxID : DHB8D0NS86")
          final sameMatch = _sameLineRegex.firstMatch(text);
          if (sameMatch != null && sameMatch.group(1) != null) {
            final rawMatched = sameMatch.group(1)!;
            if (!_isAmountOrBalance(rawMatched)) {
              final id = _cleanId(rawMatched);
              if (_isValidCandidate(id, isKeywordMatched: true)) {
                candidates.add(_TrxCandidate(
                  id: id,
                  yPosition: yPos,
                  confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
                  isKeywordMatched: true,
                ));
              }
            }
          }

          // 2. Multiline keyword match (keyword on line i, ID on line i+1 to i+3 or spatially below)
          if (_keywordHeaderRegex.hasMatch(text) || _containsKeyword(text)) {
            // Spatial check: find lines positioned directly beneath this keyword in the same column
            for (int j = 0; j < textLines.length; j++) {
              if (j == i) continue;
              final targetLine = textLines[j];
              final tBox = targetLine.boundingBox;
              final lBox = line.boundingBox;

              final isBelow = tBox.top >= lBox.top && (tBox.top - lBox.bottom) <= 250;
              final hasHorizOverlap = (tBox.left < lBox.right && tBox.right > lBox.left);

              if (isBelow && hasHorizOverlap) {
                final targetText = targetLine.text.trim();
                if (_isAmountOrBalance(targetText)) continue;

                final tokenMatch = _trxTokenRegex.firstMatch(targetText);
                if (tokenMatch != null) {
                  final id = _cleanId(tokenMatch.group(1)!);
                  if (_isValidCandidate(id, isKeywordMatched: true)) {
                    candidates.add(_TrxCandidate(
                      id: id,
                      yPosition: tBox.bottom.toDouble(),
                      confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
                      isKeywordMatched: true,
                    ));
                  }
                }
              }
            }

            // Sequential subsequent lines check
            for (int j = i + 1; j <= i + 3 && j < textLines.length; j++) {
              final nextLine = textLines[j];
              final nextText = nextLine.text.trim();
              if (_isAmountOrBalance(nextText)) continue;

              final tokenMatch = _trxTokenRegex.firstMatch(nextText);
              if (tokenMatch != null) {
                final id = _cleanId(tokenMatch.group(1)!);
                if (_isValidCandidate(id, isKeywordMatched: true)) {
                  candidates.add(_TrxCandidate(
                    id: id,
                    yPosition: nextLine.boundingBox.bottom.toDouble(),
                    confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
                    isKeywordMatched: true,
                  ));
                  break;
                }
              }
            }
          }

          // 3. Fallback scan on non-amount lines
          if (!_isAmountOrBalanceLine(text)) {
            final words = text.split(RegExp(r'\s+'));
            for (final word in words) {
              if (_isAmountOrBalance(word)) continue;
              final cleaned = _cleanId(word);
              if (_isValidCandidate(cleaned, isKeywordMatched: false)) {
                candidates.add(_TrxCandidate(
                  id: cleaned,
                  yPosition: yPos,
                  confidenceScore: _computeCandidateScore(id: cleaned, isKeywordMatched: false),
                  isKeywordMatched: false,
                ));
              }
            }
          }
        }

        final best = _pickBestCandidate(candidates);
        if (best != null && best.isNotEmpty) {
          return best;
        }
      }

      // Fallback to text parser if bounding box extraction found nothing
      return parseTransactionIdFromText(recognizedText.text);
    } catch (e) {
      debugPrint('[TransactionIdExtractor] Error recognizing text: $e');
      return null;
    }
  }

  /// Parses text from OCR to extract a Transaction ID.
  /// Uses keyword matching, format validation, and confidence ranking.
  static String? parseTransactionIdFromText(String fullText) {
    if (fullText.trim().isEmpty) return null;

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final List<_TrxCandidate> candidates = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final yPos = i.toDouble();

      // Check 1: Same line keyword
      final sameMatch = _sameLineRegex.firstMatch(line);
      if (sameMatch != null && sameMatch.group(1) != null) {
        final rawMatched = sameMatch.group(1)!;
        if (!_isAmountOrBalance(rawMatched)) {
          final id = _cleanId(rawMatched);
          if (_isValidCandidate(id, isKeywordMatched: true)) {
            candidates.add(_TrxCandidate(
              id: id,
              yPosition: yPos,
              confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
              isKeywordMatched: true,
            ));
          }
        }
      }

      // Check 2: Multiline keyword
      if (_keywordHeaderRegex.hasMatch(line) || _containsKeyword(line)) {
        for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
          final nextLine = lines[j];
          if (_isAmountOrBalance(nextLine)) continue;

          final tokenMatch = _trxTokenRegex.firstMatch(nextLine);
          if (tokenMatch != null) {
            final id = _cleanId(tokenMatch.group(1)!);
            if (_isValidCandidate(id, isKeywordMatched: true)) {
              candidates.add(_TrxCandidate(
                id: id,
                yPosition: j.toDouble(),
                confidenceScore: _computeCandidateScore(id: id, isKeywordMatched: true),
                isKeywordMatched: true,
              ));
              break;
            }
          }
        }
      }

      // Check 3: Scan words for MFS patterns on lines that are NOT balance/amount lines
      if (!_isAmountOrBalanceLine(line)) {
        final words = line.split(RegExp(r'\s+'));
        for (final word in words) {
          if (_isAmountOrBalance(word)) continue;
          final cleaned = _cleanId(word);
          if (_isValidCandidate(cleaned, isKeywordMatched: false)) {
            candidates.add(_TrxCandidate(
              id: cleaned,
              yPosition: yPos,
              confidenceScore: _computeCandidateScore(id: cleaned, isKeywordMatched: false),
              isKeywordMatched: false,
            ));
          }
        }
      }
    }

    return _pickBestCandidate(candidates);
  }

  /// Picks the optimal candidate based on keyword priority, format confidence, and position.
  static String? _pickBestCandidate(List<_TrxCandidate> candidates) {
    if (candidates.isEmpty) return null;

    // Prefer keyword-matched candidates if any exist
    final keywordCandidates = candidates.where((c) => c.isKeywordMatched).toList();
    final pool = keywordCandidates.isNotEmpty ? keywordCandidates : candidates;

    // Deduplicate candidates, keeping highest score and tie-breaking by largest Y-position
    final Map<String, _TrxCandidate> uniqueMap = {};
    for (final c in pool) {
      if (!uniqueMap.containsKey(c.id)) {
        uniqueMap[c.id] = c;
      } else {
        final existing = uniqueMap[c.id]!;
        if (c.confidenceScore > existing.confidenceScore ||
            (c.confidenceScore == existing.confidenceScore && c.yPosition > existing.yPosition)) {
          uniqueMap[c.id] = c;
        }
      }
    }

    final uniqueList = uniqueMap.values.toList();

    // Sort primarily by confidenceScore descending, then by yPosition descending (bottom-most)
    uniqueList.sort((a, b) {
      final scoreComp = b.confidenceScore.compareTo(a.confidenceScore);
      if (scoreComp != 0) return scoreComp;
      return b.yPosition.compareTo(a.yPosition);
    });

    final picked = uniqueList.first.id;
    debugPrint('[TransactionIdExtractor] Candidates: ${uniqueList.map((e) => "${e.id} (score=${e.confidenceScore}, y=${e.yPosition.toInt()})").join(", ")}');
    debugPrint('[TransactionIdExtractor] Selected Transaction ID: $picked');
    return picked;
  }

  /// Computes confidence score for candidate IDs.
  static int _computeCandidateScore({
    required String id,
    required bool isKeywordMatched,
  }) {
    int score = 0;

    // Direct keyword match provides massive confidence
    if (isKeywordMatched) {
      score += 100;
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(id).length;
    final digitCount = RegExp(r'[0-9]').allMatches(id).length;

    // bKash standard format: 10 chars, uppercase alphanumeric with letters and digits
    if (id.length == 10 && letterCount >= 2 && digitCount >= 2) {
      score += 50;
    } else if (id.length == 8 && letterCount >= 2 && digitCount >= 2) {
      // Nagad standard format: 8 chars
      score += 45;
    } else if (id.startsWith('RC') && id.length >= 10) {
      // Rocket format
      score += 40;
    } else if (id.length == 10) {
      score += 30;
    } else if (id.length >= 8 && id.length <= 12) {
      score += 20;
    }

    return score;
  }

  /// Determines if a raw token represents a monetary amount or balance instead of a TrxID.
  static bool _isAmountOrBalance(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;

    // Matches numbers with decimal point/comma, e.g. 580.02, T580.02, ৳580.02, 60.00, 1,500.00
    if (RegExp(r'[0-9]+[.,][0-9]{1,2}(?!\w)').hasMatch(trimmed)) {
      return true;
    }

    // Matches currency prefix followed strictly by numbers, e.g. T58002, ৳58002, TK500, BDT100
    if (RegExp(r'^(?:[৳\$€£]|TK|BDT|[TBtb])[0-9]+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Matches numbers with currency suffix, e.g. 60৳, 500Tk
    if (RegExp(r'^[0-9]+(?:[৳]|TK|BDT)$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Determines if a line is a balance/amount/charge line that should not yield raw fallback TrxID candidates.
  static bool _isAmountOrBalanceLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('ব্যালেন্স') ||
        lower.contains('নতুন ব্যালেন্স') ||
        lower.contains('সর্বমোট') ||
        lower.contains('পরিমাণ') ||
        lower.contains('চার্জ') ||
        lower.contains('মোট টাকা') ||
        lower.contains('ফি') ||
        lower.contains('খরচ') ||
        lower.contains('balance') ||
        lower.contains('new balance') ||
        lower.contains('total amount') ||
        lower.contains('charge') ||
        lower.contains('fee');
  }

  static bool _containsKeyword(String text) {
    final lower = text.toLowerCase();
    return lower.contains('trxid') ||
        lower.contains('trx id') ||
        lower.contains('trx-id') ||
        lower.contains('trx #') ||
        lower.contains('txn id') ||
        lower.contains('txnid') ||
        lower.contains('txn-id') ||
        lower.contains('txn #') ||
        lower.contains('transaction id') ||
        lower.contains('transaction no') ||
        lower.contains('tran id') ||
        lower.contains('trans id') ||
        text.contains('ট্রানজেকশন আইডি') ||
        text.contains('ট্রানজ্যাকশন আইডি') ||
        text.contains('ট্রানজেকশান আইডি') ||
        text.contains('ট্রানজেকশন নং') ||
        text.contains('ট্রানজ্যাকশন নং') ||
        text.contains('ট্রানজেকশন নম্বর') ||
        text.contains('লেনদেন আইডি') ||
        text.contains('লেনদেন নং');
  }

  static String _cleanId(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  static bool _isValidCandidate(String text, {bool isKeywordMatched = false}) {
    // Valid Bangladeshi MFS TrxIDs:
    // bKash: 10 alphanumeric chars
    // Nagad: 8 alphanumeric chars
    // Rocket: 10-12 chars (or 8-10 with 'RC')
    // Upay: 10 alphanumeric chars
    // Minimum valid length is 8.
    if (text.length < 8 || text.length > 18) return false;

    // Discard phone numbers (Bangladeshi numbers starting with 01 or 8801)
    if (RegExp(r'^(?:\+?88)?01[3-9][0-9]{8}$').hasMatch(text)) {
      return false;
    }
    if (text.startsWith('01') && text.length == 11 && RegExp(r'^[0-9]+$').hasMatch(text)) {
      return false;
    }
    if (text.startsWith('8801') && text.length == 13 && RegExp(r'^[0-9]+$').hasMatch(text)) {
      return false;
    }

    // Discard pure numeric tokens unless explicitly matched by keyword (e.g. Rocket 10-12 digits)
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      if (!isKeywordMatched || text.length < 10) {
        return false;
      }
    }

    // Discard currency amounts misread as T/B/৳ followed strictly by numbers (e.g. T58002, B50000)
    if (RegExp(r'^(?:[TB৳]|TK|BDT)[0-9]+$', caseSensitive: false).hasMatch(text)) {
      return false;
    }

    // Discard timestamps (e.g. 1030AM, 0936PM)
    if (RegExp(r'^[0-9]{3,4}(?:AM|PM)$', caseSensitive: false).hasMatch(text)) {
      return false;
    }

    // Discard dates in DDMMYYYY format
    if (RegExp(r'^(?:0[1-9]|[12][0-9]|3[01])(?:0[1-9]|1[012])(?:19|20)\d\d$').hasMatch(text)) {
      return false;
    }

    // Discard common app UI words and false-positives
    const blacklist = {
      'SUCCESS', 'SUCCESSFUL', 'PAYMENT', 'SENDMONEY', 'RECEIPT',
      'CHARGES', 'STATEMENT', 'CUSTOMER', 'MERCHANT', 'REFERENCE',
      'COMPLETED', 'CONFIRMED', 'TOTALAMOUNT', 'AIRTIME', 'TRANSFER',
      'CASHBACK', 'VERIFIED', 'SECURITY', 'NOTIFICATION', 'AVAILABLE',
      'BANGLADESH', 'DETAILS', 'SUMMARY', 'ACCOUNT', 'BALANCE',
      'STEADFAST', 'DELIVERY', 'CHARGE', 'AMOUNT', 'TRANSACTION',
      'PHONE', 'NUMBER', 'BILLPAY', 'CASHIN', 'CASHOUT', 'OCTOBER',
      'NOVEMBER', 'DECEMBER', 'JANUARY', 'FEBRUARY', 'WEDNESDAY',
      'THURSDAY', 'TUESDAY', 'SATURDAY', 'SUNDAY', 'MONDAY',
      'HOMEPAGE', 'SETTINGS', 'HISTORY', 'CONTACT', 'MOBILE',
      'BKASH', 'NAGAD', 'ROCKET', 'UPAY', 'TAP', 'FILTER', 'INBOX',
      'SEARCH', 'ISLAMIBANK', 'REWARDS', 'REWARD', 'POINTS', 'POINT',
      'SEND', 'MONEY'
    };

    if (blacklist.contains(text.toUpperCase())) return false;

    // Discard single letter with 4+ digits (e.g. T58002, B6000) unless explicitly keyword matched
    final letterCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    final digitCount = RegExp(r'[0-9]').allMatches(text).length;

    if (letterCount == 0 && !isKeywordMatched) return false;
    if (letterCount == 1 && digitCount >= 4 && !isKeywordMatched) return false;

    return true;
  }

  /// Disposes the TextRecognizer resource.
  static void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}

