typedef Coordinates = ({double latitude, double longitude});

abstract interface class GeocodingGateway {
  Future<Coordinates?> locate(String address);
}
