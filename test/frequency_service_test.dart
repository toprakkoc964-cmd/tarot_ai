import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarot_ai/src/core/frequency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetches a fresh birth-frequency comment when the local day changes',
      () async {
    var now = DateTime(2026, 6, 1, 23, 55);
    final requestedDays = <String>[];
    final service = FrequencyService(
      now: () => now,
      fetcher: ({
        required birthDate,
        required day,
        required lang,
      }) async {
        requestedDays.add(day);
        return 'Daily frequency insight prepared for $day.';
      },
    );

    final first = await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );
    final cached = await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );
    now = DateTime(2026, 6, 2, 0, 5);
    final nextDay = await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );

    expect(first, cached);
    expect(nextDay, isNot(first));
    expect(requestedDays, ['2026-06-01', '2026-06-02']);
  });

  test('does not present a previous-day comment when refresh fails', () async {
    var now = DateTime(2026, 6, 1, 12);
    var shouldFail = false;
    final service = FrequencyService(
      now: () => now,
      fetcher: ({
        required birthDate,
        required day,
        required lang,
      }) async {
        if (shouldFail) throw StateError('network_unavailable');
        return 'A complete daily frequency insight for $day.';
      },
    );

    final first = await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );
    now = DateTime(2026, 6, 2, 12);
    shouldFail = true;
    final failedRefresh = await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );

    expect(failedRefresh, isNot(first));
    expect(failedRefresh, isNotEmpty);
  });

  test('refreshes when the saved birth date changes on the same day', () async {
    final requestedBirthDates = <String>[];
    final service = FrequencyService(
      now: () => DateTime(2026, 6, 1, 12),
      fetcher: ({
        required birthDate,
        required day,
        required lang,
      }) async {
        requestedBirthDates.add(birthDate);
        return 'A complete daily insight for birth date $birthDate.';
      },
    );

    await service.getDailyComment(
      userBirthDate: '1995-04-20',
      lang: 'en',
    );
    await service.getDailyComment(
      userBirthDate: '1995-04-21',
      lang: 'en',
    );

    expect(requestedBirthDates, ['1995-04-20', '1995-04-21']);
  });
}
