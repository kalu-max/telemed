import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// End-to-end message encryption using AES-256-GCM.
///
/// Each chat derives a symmetric key from a shared secret (e.g. chatId +
/// both user IDs). Messages are encrypted before sending and decrypted on
/// receipt.  The backend never sees plaintext.
class ChatEncryptionService {
  static const int _keyLength = 32; // 256 bits
  static const int _nonceLength = 12; // 96 bits for GCM

  final Uint8List _key;

  ChatEncryptionService._(this._key);

  /// Derive a per-chat key from a shared secret string.
  factory ChatEncryptionService.fromSharedSecret(String secret) {
    // PBKDF2 with SHA-256: deterministic key from any string
    final salt = Uint8List.fromList(utf8.encode('telemed-e2e-salt'));
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 10000, _keyLength));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(secret)));
    return ChatEncryptionService._(key);
  }

  /// Encrypt a plaintext message. Returns base64 string of nonce + ciphertext + tag.
  String encrypt(String plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)));

    final output = Uint8List(cipher.getOutputSize(plaintextBytes.length));
    var offset = cipher.processBytes(plaintextBytes, 0, plaintextBytes.length, output, 0);
    offset += cipher.doFinal(output, offset);

    // Prepend nonce to ciphertext+tag
    final combined = Uint8List(_nonceLength + offset);
    combined.setRange(0, _nonceLength, nonce);
    combined.setRange(_nonceLength, combined.length, output.sublist(0, offset));

    return base64Encode(combined);
  }

  /// Decrypt a base64 string produced by [encrypt]. Returns plaintext.
  String decrypt(String encryptedBase64) {
    final combined = base64Decode(encryptedBase64);
    final nonce = Uint8List.sublistView(combined, 0, _nonceLength);
    final ciphertextAndTag = Uint8List.sublistView(combined, _nonceLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)));

    final output = Uint8List(cipher.getOutputSize(ciphertextAndTag.length));
    var offset = cipher.processBytes(ciphertextAndTag, 0, ciphertextAndTag.length, output, 0);
    offset += cipher.doFinal(output, offset);

    return utf8.decode(output.sublist(0, offset));
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}
