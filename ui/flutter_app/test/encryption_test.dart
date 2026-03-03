import 'package:flutter_test/flutter_test.dart';
import 'package:bova_player_flutter/core/security/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    test('加密和解密应该返回原始文本', () {
      // 测试数据
      const plaintext = 'myPassword123';
      const masterPassword = 'userPassword456';
      const userId = 'user-id-789';

      print('原始密码: $plaintext');
      print('用户密码: $masterPassword');
      print('用户ID: $userId');

      // 加密
      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId,
      );
      print('加密后: $encrypted');

      // 解密
      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        masterPassword,
        userId,
      );
      print('解密后: $decrypted');

      // 验证
      expect(decrypted, equals(plaintext));
    });

    test('不同的用户密码应该无法解密', () {
      const plaintext = 'myPassword123';
      const masterPassword1 = 'userPassword456';
      const masterPassword2 = 'differentPassword';
      const userId = 'user-id-789';

      // 用密码1加密
      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword1,
        userId,
      );

      // 用密码2解密应该失败或得到错误结果
      expect(() {
        final decrypted = EncryptionService.decryptWithMasterPassword(
          encrypted,
          masterPassword2,
          userId,
        );
        // 如果没有抛出异常，解密结果应该不等于原文
        expect(decrypted, isNot(equals(plaintext)));
      }, returnsNormally);
    });

    test('不同的用户ID应该无法解密', () {
      const plaintext = 'myPassword123';
      const masterPassword = 'userPassword456';
      const userId1 = 'user-id-789';
      const userId2 = 'different-user-id';

      // 用userId1加密
      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId1,
      );

      // 用userId2解密应该失败或得到错误结果
      expect(() {
        final decrypted = EncryptionService.decryptWithMasterPassword(
          encrypted,
          masterPassword,
          userId2,
        );
        // 如果没有抛出异常，解密结果应该不等于原文
        expect(decrypted, isNot(equals(plaintext)));
      }, returnsNormally);
    });

    test('空字符串加密解密', () {
      const plaintext = '';
      const masterPassword = 'userPassword456';
      const userId = 'user-id-789';

      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId,
      );
      print('空字符串加密后: $encrypted');

      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        masterPassword,
        userId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('特殊字符加密解密', () {
      const plaintext = '!@#\$%^&*()_+-=[]{}|;:,.<>?/~`';
      const masterPassword = 'userPassword456';
      const userId = 'user-id-789';

      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId,
      );
      print('特殊字符加密后: $encrypted');

      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        masterPassword,
        userId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('中文字符加密解密', () {
      const plaintext = '我的密码123';
      const masterPassword = 'userPassword456';
      const userId = 'user-id-789';

      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId,
      );
      print('中文字符加密后: $encrypted');

      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        masterPassword,
        userId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('长文本加密解密', () {
      const plaintext = 'This is a very long password with many characters to test the encryption and decryption process. It should work correctly regardless of the length of the input text.';
      const masterPassword = 'userPassword456';
      const userId = 'user-id-789';

      final encrypted = EncryptionService.encryptWithMasterPassword(
        plaintext,
        masterPassword,
        userId,
      );
      print('长文本加密后长度: ${encrypted.length}');

      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        masterPassword,
        userId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('测试实际场景 - 模拟云端数据', () {
      // 模拟实际使用场景
      const serverPassword = 'embyServerPassword123';
      const userPassword = 'myAccountPassword';
      const userId = 'abc-123-def-456';

      print('\n=== 实际场景测试 ===');
      print('服务器密码: $serverPassword');
      print('用户密码: $userPassword');
      print('用户ID: $userId');

      // 1. 上传到云端（加密）
      final encrypted = EncryptionService.encryptWithMasterPassword(
        serverPassword,
        userPassword,
        userId,
      );
      print('上传到云端（加密）: $encrypted');

      // 2. 从云端下载（解密）
      final decrypted = EncryptionService.decryptWithMasterPassword(
        encrypted,
        userPassword,
        userId,
      );
      print('从云端下载（解密）: $decrypted');

      expect(decrypted, equals(serverPassword));
      print('✅ 测试通过！');
    });
  });
}
