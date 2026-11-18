import 'package:domain/domain.dart';

import 'ports/washer_repository.dart';

final class GetWashers {
  const GetWashers({required this.washers});

  final WasherRepository washers;

  Future<List<Washer>> call() => washers.washers();
}
