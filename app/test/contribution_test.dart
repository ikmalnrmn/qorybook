import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/models/contribution.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('format rupiah', () {
    expect(rupiah(0), 'Rp 0');
    expect(rupiah(5000), 'Rp 5.000');
    expect(rupiah(1250000), 'Rp 1.250.000');
  });

  test('20% donasi untuk pendidikan anak yatim dan dhuafa', () {
    expect(Contribution(amount: 50000, date: DateTime(2026)).charityShare, 10000);
    expect(Contribution(amount: 25000, date: DateTime(2026)).charityShare, 5000);
  });

  test('kontribusi tersimpan, urut terbaru, dan bisa dihapus', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.open();
    final old = Contribution(amount: 10000, date: DateTime(2026, 9, 1), note: 'pertama');
    final recent = Contribution(amount: 25000, date: DateTime(2026, 10, 1));
    await settings.addContribution(old);
    await settings.addContribution(recent);

    final reopened = await SettingsStore.open();
    expect(reopened.contributions.map((c) => c.amount), [25000, 10000]);
    expect(reopened.contributions.last.note, 'pertama');

    await reopened.removeContribution(reopened.contributions.first);
    expect(reopened.contributions.single.amount, 10000);
  });
}
