import 'package:flutter_test/flutter_test.dart';
import 'package:dadu/services/transaction_id_extractor.dart';

void main() {
  group('TransactionIdExtractor parseTransactionIdFromText', () {
    test('extracts bottom-most TrxID from bKash inbox screenshot with bottom sheet details popup', () {
      const ocrText = '''
ইনবক্স
লেনদেনসমূহ নোটিফিকেশন 3
TrxID বা নাম্বার দিয়ে খুঁজুন ফিল্টার
গত ৩০ দিনের লেনদেন

সেন্ড মানি - ৳60.00
01689568056 09:36pm 11/08/26
TrxID : DHB8D0NS86

ব্যাংক টু বিকাশ + ৳50.00
Islami Bank 03:58pm 07/08/26
TrxID : DH727T001K

সেন্ড মানি - ৳30.00
01832386087 03:27pm 02/08/26
TrxID : DH321CQD2N

সেন্ড মানি বন্ধ
একাউন্ট সময়
01689568056 09:36pm 11/08/26
পরিমাণ চার্জ
৳60.00 ৳0.00
ট্রানজেকশন আইডি রেফারেন্স
DHB8D0NS86
সেন্ড মানি শেয়ার
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'DHB8D0NS86');
    });

    test('extracts bKash TrxID on same line', () {
      const ocrText = '''
bKash
Send Money
Successful
Time: 26/08/2026 18:30
TrxID: BL489QZX87
Amount: ৳130.00
Charge: ৳0.00
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'BL489QZX87');
    });

    test('extracts bKash TrxID with multiline layout', () {
      const ocrText = '''
bKash
Payment Successful
Transaction ID
9A12BC34DE
Reference: DADU
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, '9A12BC34DE');
    });

    test('extracts Nagad Txn ID', () {
      const ocrText = '''
Nagad
Send Money Successful
Txn ID: 72K83M9A
Total: ৳70.00
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, '72K83M9A');
    });

    test('extracts Bangla keyword ট্রানজেকশন আইডি', () {
      const ocrText = '''
বিকাশ
টাকা পাঠানো সফল হয়েছে
ট্রানজেকশন আইডি: CLM39X1099
মোট টাকা: ৳130.00
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'CLM39X1099');
    });

    test('extracts Rocket / general transaction ID with spaces or colons', () {
      const ocrText = '''
DBBL Rocket
Bill Pay
Tran ID : RC89230147
Amount: 130
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'RC89230147');
    });

    test('ignores middle phone numbers and picks bottom-most transaction ID', () {
      const ocrText = '''
bKash Send Money
Receiver: 01712345678
Amount: 130.00
Reference: 01899999999
TrxID: BTM9876543
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'BTM9876543');
    });

    test('picks the bottom-most transaction ID when top, middle, and bottom IDs exist', () {
      const ocrText = '''
History
TrxID: TOP1234567
Amount: ৳500.00

TrxID: MID5555555
Amount: ৳400.00

TrxID: BTM9876543
Amount: ৳200.00
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'BTM9876543');
    });

    test('picks bottom-most multiline ID over middle ID', () {
      const ocrText = '''
Header
Transaction ID
MID5555555

Footer
Transaction ID
BTM1234567
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'BTM1234567');
    });

    test('picks the bottom-most transaction ID when multiple raw tokens exist without keyword', () {
      const ocrText = '''
Statement
TOP9876543 500.00 SUCCESS
MID5555555 400.00 SUCCESS
BTM1234567 200.00 SUCCESS
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'BTM1234567');
    });

    test('returns null for empty text or irrelevant text without transaction id', () {
      const ocrText = '''
Random picture
Hello world
No numbers here
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, isNull);
    });

    test('extracts DJ80KXYKIA from bKash confirmation receipt and ignores balance ৳580.02 (not T58002)', () {
      const ocrText = '''
Send Money - now
10:30am 08/10/2026
আপনার সেন্ড মানি সফল হয়েছে
01737163498
01737163498
সময়
10:30am 08/10/26
ট্রানজেকশন আইডি
DJ80KXYKIA
সর্বমোট
৳60.00
+ চার্জ প্রযোজ্য নয়
নতুন ব্যালেন্স
৳580.02
রেফারেন্স
অটো পে চালু করুন শেয়ার
আপনি অর্জন করেছেন বিকাশ রিওয়ার্ড পয়েন্ট
হোম-এ ফিরে যাই
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'DJ80KXYKIA');
    });

    test('extracts DJ80KXYKIA even when Latin OCR misreads Bengali and balance is T580.02', () {
      const ocrText = '''
Send Money - now
10:30am 08/10/2026
01737163498
10:30am 08/10/26
DJ80KXYKIA
T60.00
T580.02
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, 'DJ80KXYKIA');
    });

    test('rejects currency amounts like T580.02 or T58002 as Transaction IDs', () {
      const ocrText = '''
Balance: T580.02
Total: T60.00
T58002
''';
      final result = TransactionIdExtractor.parseTransactionIdFromText(ocrText);
      expect(result, isNull);
    });
  });
}

