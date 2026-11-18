import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

const businessTimeZone = 'Europe/Belgrade';

final tz.Location _location = _loadLocation();

tz.Location _loadLocation() {
  data.initializeTimeZones();
  return tz.getLocation(businessTimeZone);
}

DateTime inBusinessTime(DateTime instant) => tz.TZDateTime.from(instant, _location);

DateTime businessDate(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    tz.TZDateTime(_location, year, month, day, hour, minute);
