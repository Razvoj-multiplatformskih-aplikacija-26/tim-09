import 'package:meta/meta.dart';

import '../errors.dart';
import '../result.dart';

/// Adresa na kojoj stoji vozilo, npr. „Knez Mihailova 6, Beograd“.
@immutable
final class Address {
  const Address._(this.text);

  final String text;

  static Result<Address> parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return const Failure(AddressMissing());
    return Success(Address._(text));
  }

  @override
  bool operator ==(Object other) => other is Address && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Address($text)';
}
