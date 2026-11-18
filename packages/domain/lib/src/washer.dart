import 'identifiers.dart';

final class Washer {
  const Washer({required this.id, required this.name, required this.hasActiveJob});

  final WasherId id;
  final String name;
  final bool hasActiveJob;
}
