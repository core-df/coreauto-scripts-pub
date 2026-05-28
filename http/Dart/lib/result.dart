// Copyright Core DF — Apache License 2.0
class CoreautoResult {
  static Map<String, dynamic> missingEnv(String vars) => {
    'status_code': 601,
    'error': 'Environment variables $vars should be defined',
  };
  static Map<String, dynamic> transportError([String message = 'inaccessible']) => {
    'status_code': 0,
    'error': message,
  };
}
