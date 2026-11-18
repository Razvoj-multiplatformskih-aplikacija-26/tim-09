import 'package:domain/domain.dart';

abstract interface class WasherRepository {
  Future<List<Washer>> washers();
}
