import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/core/router/app_router.dart';

void main() {
  String? redirect(String path, {bool loggedIn = true, bool complete = true}) =>
      authRedirect(path: path, loggedIn: loggedIn, profileComplete: complete, isDev: false);

  test('a brand-new driver on a sign-in screen goes to registration, not home', () {
    for (final path in ['/verify', '/email-login', '/email-signup', '/verify-email']) {
      expect(redirect(path, complete: false), '/registration', reason: path);
    }
  });

  test('a complete driver on a sign-in screen goes home', () {
    expect(redirect('/verify'), '/home');
  });

  test('signed out on a private screen goes to intro', () {
    expect(redirect('/home', loggedIn: false), '/intro');
  });

  test('registration itself is not redirected', () {
    expect(redirect('/registration', complete: false), isNull);
  });
}
