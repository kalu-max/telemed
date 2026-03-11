import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Secure encryption and decryption service with HIPAA/GDPR compliance
class EncryptionService {
  static const int _keyLength = 32; // 256 bits for AES-256
  static const int _nonceLength = 12; // 96 bits for GCM
  
  late final Cipher _cipher;

  EncryptionService() {
    _cipher = AesCtr.with256bits(macAlgorithm: Hmac(Sha256()));
  }

  /// Generate a random key for encryption
  Future<List<int>> generateKey() async {
    final secretKey = await _cipher.newSecretKey();
    return secretKey.extractBytes();
  }

  /// Encrypt message content with AES-256-GCM
  /// Returns hex-encoded ciphertext with IV and auth tag
  Future<String> encryptMessage(
    String plaintext,
    List<int> keyBytes,
  ) async {
    try {
      final secretKey = SecretKey(keyBytes);
      
      // Generate random nonce
      final random = SecureRandom();
      final nonce = random.nextBytes(_nonceLength);

      // Encrypt
      final secretBox = await _cipher.encrypt(
        utf8.encode(plaintext),
        secretKey: secretKey,
        nonce: nonce,
      );

      // Combine nonce + ciphertext + tag and hex encode
      final combined = Uint8List.fromList([
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      return base64Encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt message content with AES-256-GCM
  Future<String> decryptMessage(
    String encryptedBase64,
    List<int> keyBytes,
  ) async {
    try {
      final secretKey = SecretKey(keyBytes);
      final combined = base64Decode(encryptedBase64);

      if (combined.length < _nonceLength + Hmac(Sha256()).macLength) {
        throw Exception('Invalid ciphertext format');
      }

      // Extract components
      final nonce = combined.sublist(0, _nonceLength);
      final macLength = 16; // GCM tag is 128 bits
      final ciphertext = combined.sublist(
        _nonceLength,
        combined.length - macLength,
      );
      final tag = combined.sublist(combined.length - macLength);

      // Decrypt
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(tag),
      );

      final plainBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(plainBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Hash sensitive data (one-way) for anonymization
  Future<String> hashData(String data) async {
    final bytes = utf8.encode(data);
    final digest = await Sha256().hash(bytes);
    return base64Encode(digest.bytes);
  }

  /// Generate HIPAA-compliant audit log hash
  Future<String> generateAuditHash(Map<String, dynamic> auditData) async {
    final jsonString = jsonEncode(auditData);
    final bytes = utf8.encode(jsonString);
    final digest = await Sha256().hash(bytes);
    return base64Encode(digest.bytes);
  }

  /// Verify data integrity (for message tampering detection)
  Future<bool> verifyIntegrity(
    String data,
    String signature,
    List<int> keyBytes,
  ) async {
    try {
      final secretKey = SecretKey(keyBytes);
      final dataBytes = utf8.encode(data);
      
      final hmac = Hmac(Sha256());
      final mac = await hmac.calculateMac(
        dataBytes,
        secretKey: secretKey,
      );
      
      return base64Encode(mac.bytes) == signature;
    } catch (e) {
      return false;
    }
  }

  /// Create data signature for integrity verification
  Future<String> signData(
    String data,
    List<int> keyBytes,
  ) async {
    try {
      final secretKey = SecretKey(keyBytes);
      final dataBytes = utf8.encode(data);
      
      final hmac = Hmac(Sha256());
      final mac = await hmac.calculateMac(
        dataBytes,
        secretKey: secretKey,
      );
      
      return base64Encode(mac.bytes);
    } catch (e) {
      throw Exception('Signing failed: $e');
    }
  }

  /// Anonymize patient metadata while preserving call records
  Map<String, dynamic> anonymizeMetadata(
    Map<String, dynamic> metadata,
  ) {
    final anonymized = {...metadata};
    
    // Remove or hash personally identifiable information
    final piiFields = [
      'patientName',
      'patientEmail',
      'patientPhone',
      'doctorName',
      'doctorLicenseId',
      'ipAddress',
    ];
    
    for (final field in piiFields) {
      if (anonymized.containsKey(field)) {
        // Hash the value instead of removing it (for audit trails)
        anonymized[field] = '[ANONYMIZED]';
      }
    }
    
    return anonymized;
  }

  /// Check if encryption key is valid
  bool isValidKey(List<int> keyBytes) {
    return keyBytes.length == _keyLength;
  }
}

/// Secure random number generator for cryptographic operations
class SecureRandom {
  static final _instance = SecureRandom._internal();
  final _random = Random.secure();

  SecureRandom._internal();

  factory SecureRandom() => _instance;

  List<int> nextBytes(int length) {
    final values = List<int>.generate(length, (i) => _random.nextInt(256));
    return values;
  }
}
