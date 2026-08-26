import 'dart:convert';
import 'package:dadu/services/transaction_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TransactionVerificationResult', () {
    test('valid result properties', () {
      final res = TransactionVerificationResult.valid(
        trxId: 'BL489QZX87',
        provider: 'bkash',
        amount: 130.0,
      );

      expect(res.isValid, isTrue);
      expect(res.isAlreadyUsed, isFalse);
      expect(res.isNotFound, isFalse);
      expect(res.isError, isFalse);
      expect(res.trxId, 'BL489QZX87');
      expect(res.provider, 'bkash');
      expect(res.amount, 130.0);
      expect(res.message, contains('BKASH'));
      expect(res.message, contains('130.00'));
    });

    test('alreadyUsed result properties', () {
      final res = TransactionVerificationResult.alreadyUsed(
        trxId: 'USED123',
        provider: 'nagad',
        amount: 150.0,
      );

      expect(res.isValid, isFalse);
      expect(res.isAlreadyUsed, isTrue);
      expect(res.isNotFound, isFalse);
      expect(res.isError, isFalse);
      expect(res.trxId, 'USED123');
      expect(res.message, contains('already been used'));
    });

    test('notFound result properties', () {
      final res = TransactionVerificationResult.notFound(trxId: 'NOT_FOUND_ID');

      expect(res.isValid, isFalse);
      expect(res.isAlreadyUsed, isFalse);
      expect(res.isNotFound, isTrue);
      expect(res.isError, isFalse);
      expect(res.message, contains('not found in database'));
    });
  });

  group('TransactionVerificationService API', () {
    test('returns unverified for empty trxId', () async {
      final service = TransactionVerificationService();
      final res = await service.verifyTransaction('   ');
      expect(res.isUnverified, isTrue);
    });

    test('verifies unused transaction successfully as valid', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/transactions/BL489QZX87'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'bkash_BL489QZX87',
              'trxId': 'BL489QZX87',
              'provider': 'bkash',
              'amount': 130.0,
              'direction': 'inflow',
              'isUsed': 0,
              'date': '2026-08-26T10:00:00Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = TransactionVerificationService(client: mockClient);
      final result = await service.verifyTransaction('BL489QZX87');

      expect(result.isValid, isTrue);
      expect(result.trxId, 'BL489QZX87');
      expect(result.provider, 'bkash');
      expect(result.amount, 130.0);
      expect(result.isUsed, isFalse);
    });

    test('flags transaction as alreadyUsed when isUsed == 1', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'nagad_NG998877',
              'trxId': 'NG998877',
              'provider': 'nagad',
              'amount': 200.0,
              'direction': 'inflow',
              'isUsed': 1,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = TransactionVerificationService(client: mockClient);
      final result = await service.verifyTransaction('NG998877');

      expect(result.isValid, isFalse);
      expect(result.isAlreadyUsed, isTrue);
      expect(result.message, contains('already been used'));
    });

    test('returns notFound when 404 is returned from API', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Transaction not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = TransactionVerificationService(client: mockClient);
      final result = await service.verifyTransaction('NON_EXISTENT_TRX');

      expect(result.isValid, isFalse);
      expect(result.isNotFound, isTrue);
      expect(result.message, contains('not found in database'));
    });

    test('marks transaction as used with PATCH /transactions/:trxId/used', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/transactions/BL489QZX87/used'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['isUsed'], 1);

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Transaction marked as used',
            'data': {'trxId': 'BL489QZX87', 'isUsed': 1}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = TransactionVerificationService(client: mockClient);
      final success = await service.markTransactionUsed('BL489QZX87');

      expect(success, isTrue);
    });
  });
}
