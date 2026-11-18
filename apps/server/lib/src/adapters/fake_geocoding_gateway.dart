import '../ports/geocoding_gateway.dart';

final class FakeGeocodingGateway implements GeocodingGateway {
  const FakeGeocodingGateway();

  @override
  Future<Coordinates?> locate(String address) async =>
      address.trim().isEmpty ? null : (latitude: 44.8176, longitude: 20.4633);
}
