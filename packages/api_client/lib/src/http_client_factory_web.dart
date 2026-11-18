import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'session_controller.dart';

const platformTransport = SessionTransport.cookie;

http.Client createHttpClient() => BrowserClient()..withCredentials = true;
