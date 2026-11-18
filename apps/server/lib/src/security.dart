import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String randomToken() {
  final random = Random.secure();
  return base64Url.encode(List.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
}

String tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();
