import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 加密服务
/// 
/// 使用 HMAC-SHA256 加密敏感数据
/// 基于用户密码的加密，支持跨设备同步
class EncryptionService {
  /// 使用主密码加密（跨设备同步）
  /// 
  /// 需要用户密码，适用于多设备同步场景
  static String encryptWithMasterPassword(
    String plaintext,
    String masterPassword,
    String userId,
  ) {
    return _encryptText(plaintext, masterPassword, userId);
  }

  /// 使用主密码解密
  static String decryptWithMasterPassword(
    String ciphertext,
    String masterPassword,
    String userId,
  ) {
    return _decryptText(ciphertext, masterPassword, userId);
  }

  /// 内部加密实现
  static String _encryptText(String plaintext, String key, String salt) {
    try {
      // 使用 HMAC-SHA256 作为简单的加密（实际应用中应使用 AES）
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(plaintext);
      final saltBytes = utf8.encode(salt);
      
      // 使用密钥和盐值计算 HMAC（不包含数据本身）
      final combined = [...saltBytes];
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(combined);
      
      // 简单的 XOR 加密（演示用，生产环境应使用 AES）
      final encrypted = <int>[];
      for (var i = 0; i < dataBytes.length; i++) {
        encrypted.add(dataBytes[i] ^ digest.bytes[i % digest.bytes.length]);
      }
      
      // 返回 base64 编码
      return base64.encode(encrypted);
    } catch (e) {
      throw Exception('加密失败: $e');
    }
  }

  /// 内部解密实现
  static String _decryptText(String ciphertext, String key, String salt) {
    try {
      final keyBytes = utf8.encode(key);
      final saltBytes = utf8.encode(salt);
      final encrypted = base64.decode(ciphertext);
      
      // 使用相同的方式计算 HMAC
      final combined = [...saltBytes];
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(combined);
      
      // XOR 解密
      final decrypted = <int>[];
      for (var i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ digest.bytes[i % digest.bytes.length]);
      }
      
      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('解密失败: $e');
    }
  }
}
