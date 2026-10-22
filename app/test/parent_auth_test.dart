import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/services/parent_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore settings;
  late ParentAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsStore.open();
    auth = ParentAuth(settings);
    await auth.setPin('2580');
  });

  test('PIN disimpan sebagai hash bergaram, bukan teks asli', () {
    expect(settings.pinHash, isNot(contains('2580')));
    expect(settings.pinSalt, isNotEmpty);
    expect(ParentAuth.hashPin('2580', settings.pinSalt!), settings.pinHash);
  });

  test('PIN benar dan salah', () async {
    expect(await auth.verify('0000'), PinCheck.wrong);
    expect(await auth.verify('2580'), PinCheck.ok);
    expect(settings.failedAttempts, 0);
  });

  test('terkunci sementara setelah 5 kali salah', () async {
    for (var i = 0; i < 4; i++) {
      expect(await auth.verify('1111'), PinCheck.wrong);
    }
    expect(await auth.verify('1111'), PinCheck.lockedOut);
    expect(auth.lockoutRemaining, isNotNull);
    // PIN benar pun ditolak selama masa kunci.
    expect(await auth.verify('2580'), PinCheck.lockedOut);
  });

  test('ganti PIN membuat PIN lama tidak berlaku', () async {
    await auth.setPin('7410');
    expect(await auth.verify('2580'), PinCheck.wrong);
    expect(await auth.verify('7410'), PinCheck.ok);
  });
}
