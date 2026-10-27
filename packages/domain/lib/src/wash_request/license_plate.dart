import 'package:meta/meta.dart';

import '../errors.dart';
import '../result.dart';

/// R2 · Registarska oznaka je u formatu „BG 123-AB“.
@immutable
final class LicensePlate {
  const LicensePlate._(this.value);

  static const example = 'BG 123-AB';
  static final _format = RegExp(r'^[A-ZČĆŽŠĐ]{2} \d{3,5}-[A-ZČĆŽŠĐ]{2}$');

  final String value;

  static Result<LicensePlate> parse(String input) {
    final value = input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!_format.hasMatch(value)) return const Failure(InvalidLicensePlate());
    return Success(LicensePlate._(value));
  }

  @override
  bool operator ==(Object other) => other is LicensePlate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'LicensePlate($value)';
}
