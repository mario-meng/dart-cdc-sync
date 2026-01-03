import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Computes SHA-1 hash of data
String hash(List<int> data) {
  final digest = sha1.convert(data);
  return digest.toString();
}

/// Computes SHA-1 hash of a string
String hashString(String data) {
  return hash(utf8.encode(data));
}

/// Generates a random hash value
String randHash() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hash(bytes);
}
