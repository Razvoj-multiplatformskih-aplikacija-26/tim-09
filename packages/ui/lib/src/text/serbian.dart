import 'package:intl/intl.dart';

const serbianLatin = 'sr_Latn';

final _date = DateFormat('EEEE, d. MMMM', serbianLatin);
final _time = DateFormat('HH:mm', serbianLatin);
final _price = NumberFormat.decimalPattern(serbianLatin);

String capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

String formatDate(DateTime moment) => capitalize(_date.format(moment));

String formatTime(DateTime moment) => _time.format(moment);

String formatDateAndTime(DateTime moment) => '${formatDate(moment)} u ${formatTime(moment)}';

String formatPrice(int rsd) => '${_price.format(rsd)} RSD';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes min';
}
