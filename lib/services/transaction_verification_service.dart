import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Represents the state of transaction verification.
enum TransactionVerificationStatus {
  unverified,
  verifying,
  valid,
  alreadyUsed,
  notFound,
  error,
}

/// Holds the parsed verification outcome and transaction metadata.
class TransactionVerificationResult {
  final TransactionVerificationStatus status;
  final String message;
  final String? trxId;
  final String? provider;
  final double? amount;
  final String? direction;
  final bool? isUsed;
  final DateTime? date;
  final Map<String, dynamic>? rawData;

  const TransactionVerificationResult({
    required this.status,
    required this.message,
    this.trxId,
    this.provider,
    this.amount,
    this.direction,
    this.isUsed,
    this.date,
    this.rawData,
  });

  bool get isValid => status == TransactionVerificationStatus.valid;
  bool get isAlreadyUsed => status == TransactionVerificationStatus.alreadyUsed;
  bool get isNotFound => status == TransactionVerificationStatus.notFound;
  bool get isError => status == TransactionVerificationStatus.error;
  bool get isVerifying => status == TransactionVerificationStatus.verifying;
  bool get isUnverified => status == TransactionVerificationStatus.unverified;

  factory TransactionVerificationResult.unverified() {
    return const TransactionVerificationResult(
      status: TransactionVerificationStatus.unverified,
      message: '',
    );
  }

  factory TransactionVerificationResult.verifying([String? message]) {
    return TransactionVerificationResult(
      status: TransactionVerificationStatus.verifying,
      message: message ?? 'Checking transaction in database...',
    );
  }

  factory TransactionVerificationResult.notFound({String? trxId, String? message}) {
    return TransactionVerificationResult(
      status: TransactionVerificationStatus.notFound,
      trxId: trxId,
      message: message ??
          'Transaction ID not found in database. Please make sure you sent the delivery charge to our number and typed the correct TrxID.',
    );
  }

  factory TransactionVerificationResult.alreadyUsed({
    String? trxId,
    String? provider,
    double? amount,
    String? message,
    Map<String, dynamic>? rawData,
  }) {
    return TransactionVerificationResult(
      status: TransactionVerificationStatus.alreadyUsed,
      trxId: trxId,
      provider: provider,
      amount: amount,
      isUsed: true,
      rawData: rawData,
      message: message ??
          'This Transaction ID has already been used for another order.',
    );
  }

  factory TransactionVerificationResult.valid({
    required String trxId,
    String? provider,
    double? amount,
    String? direction,
    DateTime? date,
    String? message,
    Map<String, dynamic>? rawData,
  }) {
    final provDisplay = (provider != null && provider.isNotEmpty)
        ? provider.toUpperCase()
        : 'MFS';
    final amtDisplay = amount != null ? ' (৳${amount.toStringAsFixed(2)})' : '';
    return TransactionVerificationResult(
      status: TransactionVerificationStatus.valid,
      trxId: trxId,
      provider: provider,
      amount: amount,
      direction: direction,
      isUsed: false,
      date: date,
      rawData: rawData,
      message: message ?? '✓ Valid $provDisplay Transaction$amtDisplay. Ready to order!',
    );
  }

  factory TransactionVerificationResult.error(String message, {String? trxId}) {
    return TransactionVerificationResult(
      status: TransactionVerificationStatus.error,
      trxId: trxId,
      message: message,
    );
  }
}

/// Service to verify transaction IDs and manage used status in Cloudflare D1 database.
class TransactionVerificationService {
  final http.Client _client;

  TransactionVerificationService({http.Client? client})
      : _client = client ?? http.Client();

  String get baseUrl {
    try {
      if (dotenv.isInitialized) {
        return dotenv.get('API_BASE_URL',
            fallback: 'https://my-api.sayadulmorsalin123.workers.dev');
      }
    } catch (_) {}
    return 'https://my-api.sayadulmorsalin123.workers.dev';
  }

  /// Verifies if a transaction ID exists in the database and whether it has already been used.
  Future<TransactionVerificationResult> verifyTransaction(
    String rawTrxId, {
    String? expectedProvider,
    double? minAmount,
  }) async {
    final cleanTrxId = rawTrxId.trim();
    if (cleanTrxId.isEmpty) {
      return TransactionVerificationResult.unverified();
    }

    try {
      final uri = Uri.parse('$baseUrl/transactions/${Uri.encodeComponent(cleanTrxId)}');
      debugPrint('[TransactionVerification] Checking TrxID: $cleanTrxId at $uri');

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      debugPrint('[TransactionVerification] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 404) {
        return TransactionVerificationResult.notFound(trxId: cleanTrxId);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] as Map<String, dynamic>?;
          if (data == null) {
            return TransactionVerificationResult.notFound(trxId: cleanTrxId);
          }

          final String trxId = data['trxId']?.toString() ?? cleanTrxId;
          final String provider = (data['provider']?.toString() ?? '').toLowerCase();
          final double? amount = (data['amount'] as num?)?.toDouble();
          final String direction = (data['direction']?.toString() ?? 'inflow').toLowerCase();
          final rawIsUsed = data['isUsed'] ?? data['used'];
          final bool isUsed = (rawIsUsed == 1 ||
              rawIsUsed == true ||
              rawIsUsed.toString() == '1' ||
              rawIsUsed.toString().toLowerCase() == 'true');

          DateTime? date;
          if (data['date'] != null) {
            try {
              date = DateTime.tryParse(data['date'].toString());
            } catch (_) {}
          }

          // Check if transaction has already been used
          if (isUsed) {
            return TransactionVerificationResult.alreadyUsed(
              trxId: trxId,
              provider: provider,
              amount: amount,
              rawData: data,
            );
          }

          // Direction check (inflow means payment received)
          if (direction == 'outflow') {
            return TransactionVerificationResult.error(
              'This transaction represents an outgoing payment rather than a received payment.',
              trxId: trxId,
            );
          }

          return TransactionVerificationResult.valid(
            trxId: trxId,
            provider: provider,
            amount: amount,
            direction: direction,
            date: date,
            rawData: data,
          );
        }
      }

      return TransactionVerificationResult.error(
        'Server returned error (${response.statusCode}). Please try again later.',
        trxId: cleanTrxId,
      );
    } on http.ClientException catch (e) {
      debugPrint('[TransactionVerification] ClientException: $e');
      return TransactionVerificationResult.error(
        'Network error: Please check your internet connection.',
        trxId: cleanTrxId,
      );
    } catch (e) {
      debugPrint('[TransactionVerification] Error: $e');
      return TransactionVerificationResult.error(
        'Verification failed: ${e.toString()}',
        trxId: cleanTrxId,
      );
    }
  }

  /// Marks a transaction ID as used (`isUsed = 1`) in the database upon successful order submission.
  Future<bool> markTransactionUsed(String rawTrxId) async {
    final cleanTrxId = rawTrxId.trim();
    if (cleanTrxId.isEmpty) return false;

    try {
      final uri = Uri.parse('$baseUrl/transactions/${Uri.encodeComponent(cleanTrxId)}/used');
      debugPrint('[TransactionVerification] Marking TrxID as used: $cleanTrxId');

      final response = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isUsed': 1}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[TransactionVerification] Mark used response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[TransactionVerification] Failed to mark transaction as used: $e');
      return false;
    }
  }
}
