import 'package:http/http.dart' as http;

import 'session_controller.dart';

const platformTransport = SessionTransport.bearer;

http.Client createHttpClient() => http.Client();
