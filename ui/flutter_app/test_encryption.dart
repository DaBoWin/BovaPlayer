import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 加密服务（修复后的版本）
class EncryptionService {
  static String encryptWithMasterPassword(
    String plaintext,
    String masterPassword,
    String userId,
  ) {
    return _encryptText(plaintext, masterPassword, userId);
  }

  static String decryptWithMasterPassword(
    String ciphertext,
    String masterPassword,
    String userId,
  ) {
    return _decryptText(ciphertext, masterPassword, userId);
  }

  static String _encryptText(String plaintext, String key, String salt) {
    try {
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(plaintext);
      final saltBytes = utf8.encode(salt);
      
      // 使用密钥和盐值计算 HMAC（不包含数据本身）
      final combined = [...saltBytes];
      final hmac = Hmac(sha256, keyBytes);
      final digest = hmac.convert(combined);
      
      // 简单的 XOR 加密
      final encrypted = <int>[];
      for (var i = 0; i < dataBytes.length; i++) {
        encrypted.add(dataBytes[i] ^ digest.bytes[i % digest.bytes.length]);
      }
      
      return base64.encode(encrypted);
    } catch (e) {
      throw Exception('加密失败: $e');
    }
  }

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

void main() {
  print('=== 加密解密测试（修复后）===\n');

  // 测试1: 基本加密解密
  print('测试1: 基本加密解密');
  const plaintext1 = 'myPassword123';
  const userPassword1 = 'userPassword456';
  const userId1 = 'user-id-789';
  
  print('原始密码: $plaintext1');
  print('用户密码: $userPassword1');
  print('用户ID: $userId1');
  
  final encrypted1 = EncryptionService.encryptWithMasterPassword(
    plaintext1,
    userPassword1,
    userId1,
  );
  print('加密后: $encrypted1');
  
  final decrypted1 = EncryptionService.decryptWithMasterPassword(
    encrypted1,
    userPassword1,
    userId1,
  );
  print('解密后: $decrypted1');
  print('结果: ${decrypted1 == plaintext1 ? "✅ 通过" : "❌ 失败"}');
  print('');

  // 测试2: 中文字符
  print('测试2: 中文字符');
  const plaintext2 = '我的密码123';
  final encrypted2 = EncryptionService.encryptWithMasterPassword(
    plaintext2,
    userPassword1,
    userId1,
  );
  print('中文字符加密后: $encrypted2');
  final decrypted2 = EncryptionService.decryptWithMasterPassword(
    encrypted2,
    userPassword1,
    userId1,
  );
  print('解密后: $decrypted2');
  print('结果: ${decrypted2 == plaintext2 ? "✅ 通过" : "❌ 失败"}');
  print('');

  // 测试3: 实际场景模拟
  print('测试3: 实际场景模拟');
  const serverPassword = 'embyServerPassword123';
  const userPassword = 'myAccountPassword';
  const userId = 'abc-123-def-456';
  
  print('服务器密码: $serverPassword');
  print('用户密码: $userPassword');
  print('用户ID: $userId');
  
  // 上传到云端（加密）
  final cloudEncrypted = EncryptionService.encryptWithMasterPassword(
    serverPassword,
    userPassword,
    userId,
  );
  print('上传到云端（加密）: $cloudEncrypted');
  
  // 从云端下载（解密）
  final cloudDecrypted = EncryptionService.decryptWithMasterPassword(
    cloudEncrypted,
    userPassword,
    userId,
  );
  print('从云端下载（解密）: $cloudDecrypted');
  print('结果: ${cloudDecrypted == serverPassword ? "✅ 通过" : "❌ 失败"}');
  print('');

  print('=== 所有测试完成 ===');
}
