import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/auth/auth_error.dart';

void main() {
  test('authentication errors tolerate non-JSON server responses', () {
    expect(
      authErrorMessage({'error': 'Wrong password'}, 'Connection error'),
      'Wrong password',
    );
    expect(
      authErrorMessage('<html>Bad Gateway</html>', 'Connection error'),
      'Connection error',
    );
    expect(authErrorMessage(null, 'Connection error'), 'Connection error');
    expect(
      authErrorMessage({'error': 500}, 'Connection error'),
      'Connection error',
    );
  });
}
