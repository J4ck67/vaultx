import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = "vaultx_aes_key";

  /*──────── AES-256 KEY ────────*/
  static Future<enc.Key> _getKey() async {
    final storedKey = await _storage.read(key: _keyName);

    if (storedKey == null) {
      final key = enc.Key.fromSecureRandom(32); // 256-bit
      await _storage.write(key: _keyName, value: key.base64);
      return key;
    }

    return enc.Key.fromBase64(storedKey);
  }

  /*──────── ENCRYPT FILE ────────*/
  static Future<File> encryptFile(File inputFile) async {
    final key = await _getKey();
    final iv = enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final bytes = await inputFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.enc',
    );

    // IV + cipher bytes
    await file.writeAsBytes(iv.bytes + encrypted.bytes);
    return file;
  }

  /*──────── DECRYPT FILE ────────*/
  static Future<File> decryptFile({
    required Uint8List encryptedBytes,
    required String originalFileName,
  }) async {
    if (encryptedBytes.length < 17) {
      throw Exception("Invalid encrypted file");
    }

    final key = await _getKey();

    final ivBytes = encryptedBytes.sublist(0, 16);
    final cipherBytes = encryptedBytes.sublist(16);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decryptedBytes = encrypter.decryptBytes(
      enc.Encrypted(cipherBytes),
      iv: iv,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$originalFileName');

    await file.writeAsBytes(decryptedBytes);
    return file;
  }
}
