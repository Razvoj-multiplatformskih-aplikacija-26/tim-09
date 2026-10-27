import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../errors.dart';
import '../result.dart';

/// R1 · Napomena za perača ima najviše [maxLength] znakova.
@immutable
final class WashNote {
  const WashNote._(this.text);

  static const maxLength = 300;

  final String text;

  static Result<WashNote> parse(String input) {
    final text = input.trim();
    final length = text.characters.length;
    if (length > maxLength) return Failure(NoteTooLong(length));
    return Success(WashNote._(text));
  }

  @override
  bool operator ==(Object other) => other is WashNote && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'WashNote("$text")';
}
