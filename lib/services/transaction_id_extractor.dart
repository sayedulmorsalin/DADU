import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class _TrxCandidate {
  final String id;
  final double yPosition;

  _TrxCandidate({
    required this.id,
    required this.yPosition,
  });
}

/// Service for recognizing text from images and extracting Transaction IDs (TrxID / Txn ID).
class TransactionIdExtractor {
  static TextRecognizer? _recognizer;

  static TextRecognizer get _instance {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Scans an image file from [imagePath] and extracts the Transaction ID.
  /// When multiple transaction IDs are present, strictly chooses the bottom-most one on the screen.
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

        final sameLineRegex = RegExp(
          r'(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি)\s*[:：\-_=\s#]\s*([A-Za-z0-9]{6,18})',
          caseSensitive: false,
        );

        final keywordHeaderRegex = RegExp(
          r'^(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি)[:：\-_=\s#]*$',
          caseSensitive: false,
        );

        for (int i = 0; i < textLines.length; i++) {
          final line = textLines[i];
          final text = line.text.trim();
          final yPos = line.boundingBox.bottom;

          // 1. Same line keyword match (e.g. "TrxID : DHB8D0NS86")
          final sameMatch = sameLineRegex.firstMatch(text);
          if (sameMatch != null && sameMatch.group(1) != null) {
            final id = _cleanId(sameMatch.group(1)!);
            if (_isValidCandidate(id)) {
              candidates.add(_TrxCandidate(id: id, yPosition: yPos));
            }
          }

          // 2. Multiline keyword match (keyword on line i, ID on line i+1 or i+2)
          if (keywordHeaderRegex.hasMatch(text) || _containsKeyword(text)) {
            for (int j = i + 1; j <= i + 2 && j < textLines.length; j++) {
              final nextLine = textLines[j];
              final tokenMatch = RegExp(r'\b([A-Za-z0-9]{6,18})\b').firstMatch(nextLine.text.trim());
              if (tokenMatch != null) {
                final id = _cleanId(tokenMatch.group(1)!);
                if (_isValidCandidate(id)) {
                  candidates.add(_TrxCandidate(id: id, yPosition: nextLine.boundingBox.bottom));
                  break;
                }
              }
            }
          }

          // 3. Scan all alphanumeric tokens in the line (e.g. bKash 10-char "DHB8D0NS86", Nagad 8-char "72K83M9A")
          final words = text.split(RegExp(r'\s+'));
          for (final word in words) {
            final cleaned = _cleanId(word);
            if (_isValidCandidate(cleaned) && _hasDigitAndLetter(cleaned)) {
              candidates.add(_TrxCandidate(id: cleaned, yPosition: yPos));
            }
          }
        }

        if (candidates.isNotEmpty) {
          // Keep the highest Y-position for each unique candidate
          final Map<String, _TrxCandidate> uniqueMap = {};
          for (final c in candidates) {
            if (!uniqueMap.containsKey(c.id) || uniqueMap[c.id]!.yPosition < c.yPosition) {
              uniqueMap[c.id] = c;
            }
          }

          final uniqueList = uniqueMap.values.toList();
          // Sort by Y-position ascending so bottom-most is last
          uniqueList.sort((a, b) => a.yPosition.compareTo(b.yPosition));

          final picked = uniqueList.last.id;
          debugPrint('[TransactionIdExtractor] Found ${uniqueList.length} candidates: ${uniqueList.map((e) => "${e.id} (y=${e.yPosition.toInt()})").join(", ")}');
          debugPrint('[TransactionIdExtractor] Selected bottom-most Transaction ID: $picked');
          return picked;
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
  /// If multiple transaction IDs exist, strictly chooses the last (bottom-most / latest) occurrence.
  static String? parseTransactionIdFromText(String fullText) {
    if (fullText.trim().isEmpty) return null;

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final List<_TrxCandidate> candidates = [];

    final sameLineRegex = RegExp(
      r'(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি)\s*[:：\-_=\s#]\s*([A-Za-z0-9]{6,18})',
      caseSensitive: false,
    );

    final keywordHeaderRegex = RegExp(
      r'^(?:Trx\s*ID|Txn\s*ID|Transaction\s*ID|Tran\s*ID|TXNID|TrxID|Transaction\s*No|Trans\s*ID|ট্রানজেকশন\s*আইডি|ট্রানজ্যাকশন\s*আইডি|ট্রানজেকশান\s*আইডি)[:：\-_=\s#]*$',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final yPos = i.toDouble();

      // Check 1: Same line keyword
      final sameMatch = sameLineRegex.firstMatch(line);
      if (sameMatch != null && sameMatch.group(1) != null) {
        final id = _cleanId(sameMatch.group(1)!);
        if (_isValidCandidate(id)) {
          candidates.add(_TrxCandidate(id: id, yPosition: yPos));
        }
      }

      // Check 2: Multiline keyword
      if (keywordHeaderRegex.hasMatch(line) || _containsKeyword(line)) {
        for (int j = i + 1; j <= i + 2 && j < lines.length; j++) {
          final nextLine = lines[j];
          final tokenMatch = RegExp(r'\b([A-Za-z0-9]{6,18})\b').firstMatch(nextLine);
          if (tokenMatch != null) {
            final id = _cleanId(tokenMatch.group(1)!);
            if (_isValidCandidate(id)) {
              candidates.add(_TrxCandidate(id: id, yPosition: j.toDouble()));
              break;
            }
          }
        }
      }

      // Check 3: Scan all words for MFS patterns
      final words = line.split(RegExp(r'\s+'));
      for (final word in words) {
        final cleaned = _cleanId(word);
        if (_isValidCandidate(cleaned) && _hasDigitAndLetter(cleaned)) {
          candidates.add(_TrxCandidate(id: cleaned, yPosition: yPos));
        }
      }
    }

    if (candidates.isNotEmpty) {
      final Map<String, _TrxCandidate> uniqueMap = {};
      for (final c in candidates) {
        if (!uniqueMap.containsKey(c.id) || uniqueMap[c.id]!.yPosition < c.yPosition) {
          uniqueMap[c.id] = c;
        }
      }

      final uniqueList = uniqueMap.values.toList();
      uniqueList.sort((a, b) => a.yPosition.compareTo(b.yPosition));

      return uniqueList.last.id;
    }

    return null;
  }

  static bool _containsKeyword(String text) {
    final lower = text.toLowerCase();
    return lower.contains('trxid') ||
        lower.contains('trx id') ||
        lower.contains('txn id') ||
        lower.contains('txnid') ||
        lower.contains('transaction id') ||
        lower.contains('tran id') ||
        text.contains('ট্রানজেকশন আইডি') ||
        text.contains('ট্রানজ্যাকশন আইডি');
  }

  static String _cleanId(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  static bool _hasDigitAndLetter(String text) {
    final hasDigit = text.contains(RegExp(r'[0-9]'));
    final hasLetter = text.contains(RegExp(r'[A-Z]'));
    return hasDigit && hasLetter;
  }

  static bool _isValidCandidate(String text) {
    if (text.length < 6 || text.length > 18) return false;

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

    // Discard pure numeric tokens (e.g. amounts, timestamps)
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
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
      'SEARCH', 'ISLAMIBANK'
    };

    if (blacklist.contains(text.toUpperCase())) return false;

    // Reject pure letter words
    final hasDigit = text.contains(RegExp(r'[0-9]'));
    if (!hasDigit) {
      return false;
    }

    return true;
  }

  /// Disposes the TextRecognizer resource.
  static void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}
