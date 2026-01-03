import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Encrypts data using AES-256-CBC
Future<Uint8List> encryptAES(Uint8List data, Uint8List key) async {
  final keyParam = KeyParameter(key);
  final iv = Uint8List(16); // Zero IV for simplicity
  final ivParams = ParametersWithIV(keyParam, iv);
  final params = PaddedBlockCipherParameters(ivParams, null);

  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  cipher.init(true, params);

  return Uint8List.fromList(cipher.process(data));
}

/// Decrypts data using AES-256-CBC
Future<Uint8List> decryptAES(Uint8List data, Uint8List key) async {
  final keyParam = KeyParameter(key);
  final iv = Uint8List(16); // Zero IV for simplicity
  final ivParams = ParametersWithIV(keyParam, iv);
  final params = PaddedBlockCipherParameters(ivParams, null);

  final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
  cipher.init(false, params);

  return Uint8List.fromList(cipher.process(data));
}
