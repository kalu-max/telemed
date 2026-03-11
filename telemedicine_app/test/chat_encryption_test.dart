import 'package:flutter_test/flutter_test.dart';
import 'package:telemedicine_app/services/chat_encryption_service.dart';

void main() {
  group('ChatEncryptionService', () {
    test('encrypts and decrypts a message correctly', () {
      final svc = ChatEncryptionService.fromSharedSecret('test-secret-key-123');
      const plaintext = 'Hello, this is a test message!';

      final encrypted = svc.encrypt(plaintext);
      expect(encrypted, isNot(equals(plaintext)));
      expect(encrypted, isNotEmpty);

      final decrypted = svc.decrypt(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('different secrets produce different ciphertexts', () {
      final svc1 = ChatEncryptionService.fromSharedSecret('secret-a');
      final svc2 = ChatEncryptionService.fromSharedSecret('secret-b');
      const msg = 'Test message';

      final enc1 = svc1.encrypt(msg);
      final enc2 = svc2.encrypt(msg);
      expect(enc1, isNot(equals(enc2)));
    });

    test('same service produces different ciphertexts (unique nonces)', () {
      final svc = ChatEncryptionService.fromSharedSecret('nonce-test');
      const msg = 'Repeated message';

      final enc1 = svc.encrypt(msg);
      final enc2 = svc.encrypt(msg);
      // Same plaintext should produce different ciphertext due to random nonce
      expect(enc1, isNot(equals(enc2)));

      // Both should decrypt to the same plaintext
      expect(svc.decrypt(enc1), equals(msg));
      expect(svc.decrypt(enc2), equals(msg));
    });

    test('handles empty string', () {
      final svc = ChatEncryptionService.fromSharedSecret('empty-test');
      final encrypted = svc.encrypt('');
      final decrypted = svc.decrypt(encrypted);
      expect(decrypted, equals(''));
    });

    test('handles unicode/emoji content', () {
      final svc = ChatEncryptionService.fromSharedSecret('unicode-test');
      const msg = 'Hello 🏥💊 Доктор 你好';
      final encrypted = svc.encrypt(msg);
      final decrypted = svc.decrypt(encrypted);
      expect(decrypted, equals(msg));
    });
  });
}
