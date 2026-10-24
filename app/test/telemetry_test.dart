import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/models/supporter.dart';
import 'package:qorybook/services/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore settings;
  late List<http.Request> sent;
  late DateTime now;
  var status = 200;

  Telemetry make({String url = 'https://x.supabase.co/'}) {
    final client = MockClient((req) async {
      sent.add(req);
      return http.Response('', status);
    });
    return Telemetry(
      settings: settings,
      client: client,
      baseUrl: url,
      anonKey: url.isEmpty ? '' : 'anon',
      now: () => now,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsStore.open();
    sent = [];
    status = 200;
    now = DateTime(2026, 10, 24, 9);
  });

  Map<String, Object?> body(int i) => jsonDecode(sent[i].body) as Map<String, Object?>;

  test('tanpa alamat backend tidak ada yang dikirim', () async {
    final t = make(url: '');
    expect(t.configured, isFalse);
    await t.ping();
    await t.event('donate_tap');
    expect(sent, isEmpty);
  });

  test('ping paling banyak sekali sehari dan memakai ID acak yang tetap', () async {
    final t = make();
    await t.ping();
    await t.ping();
    expect(sent, hasLength(1));
    expect(sent.single.url.toString(), 'https://x.supabase.co/rest/v1/rpc/ping');
    expect(sent.single.headers['apikey'], 'anon');
    expect(body(0)['p_install_id'], settings.installId);
    expect((body(0)['p_install_id'] as String), hasLength(32));

    now = DateTime(2026, 10, 25, 9);
    await t.ping();
    expect(sent, hasLength(2));
  });

  test('ping yang gagal diulang, dan kegagalan tidak melempar', () async {
    status = 500;
    final t = make();
    await t.ping();
    status = 200;
    await t.ping();
    expect(sent, hasLength(2));
  });

  test('dimatikan orang tua: tidak ada ping maupun event', () async {
    settings.telemetryEnabled = false;
    final t = make();
    await t.ping();
    await t.event('donate_tap');
    expect(sent, isEmpty);
  });

  test('event donasi membawa nominal saja', () async {
    await make().event('donation_recorded', data: {'amount': 50000});
    expect(body(0)['p_type'], 'donation_recorded');
    expect(body(0)['p_data'], {'amount': 50000});
  });

  test('perkenalan: kirim hanya bila setuju; tanpa setuju dihapus dari server', () async {
    final t = make();
    expect(await t.saveSupporter(const Supporter(nickname: 'Bunda Rani', contact: 'a@b.id', consent: true)), isTrue);
    expect(sent.single.url.path, endsWith('/register_supporter'));
    expect(body(0)['p_nickname'], 'Bunda Rani');
    expect(settings.supporter?.nickname, 'Bunda Rani');

    await t.saveSupporter(const Supporter(nickname: 'Bunda Rani', consent: false));
    expect(sent.last.url.path, endsWith('/forget_supporter'));

    await t.forgetSupporter();
    expect(settings.supporter, isNull);
  });
}
