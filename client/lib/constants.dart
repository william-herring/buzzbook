// Where the Flask server is running. Defaults to William's laptop.
// To point at a different server without editing this file, run e.g.
//   flutter run -d chrome --dart-define=API_URL=http://localhost:3000
const String apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://192.168.1.137:3000');
