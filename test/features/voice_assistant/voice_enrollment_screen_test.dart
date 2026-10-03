import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/wake_word/voice_profile_service.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/app/theme/app_theme.dart';
import 'package:viernes/core/widgets/liquid.dart';
import 'package:viernes/features/voice_assistant/presentation/voice_enrollment_screen.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

import '../../helpers/fake_speech.dart';
import '../../helpers/fake_wake_word.dart';

void main() {
  late FakeVoiceProfileService voice;
  late FakeWakeWordService wake;

  Future<void> pump(WidgetTester tester, {bool enrolled = false}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    voice = FakeVoiceProfileService(enrolled: enrolled);
    wake = FakeWakeWordService()..ownModel = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          voiceProfileServiceProvider.overrideWithValue(voice),
          wakeWordServiceProvider.overrideWithValue(wake),
          speechRecognizerProvider.overrideWithValue(FakeSpeechRecognizer()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const VoiceEnrollmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapOrb(WidgetTester tester) async {
    await tester.tap(find.byType(VoiceOrb));
    await tester.pumpAndSettle();
  }

  testWidgets('registra la voz con cinco grabaciones', (tester) async {
    await pump(tester);
    expect(find.text('Enséñale tu voz a Viernes'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('0 de 5'), findsOneWidget);

    // Una grabación sin voz no cuenta y explica qué pasó.
    voice.nextProblems.add(SampleProblem.quiet);
    await tapOrb(tester);
    expect(find.textContaining('No te escuché'), findsOneWidget);
    expect(find.text('0 de 5'), findsOneWidget);

    for (var i = 0; i < VoiceProfileService.samplesNeeded; i++) {
      await tapOrb(tester);
    }

    expect(voice.enrolled, isTrue);
    expect(find.text('Listo, ya reconozco tu voz'), findsOneWidget);
    expect(find.text('Activar «Viernes»'), findsOneWidget);
  });

  testWidgets('con la voz registrada se puede probar', (tester) async {
    await pump(tester, enrolled: true);
    expect(find.text('Tu voz ya está registrada'), findsOneWidget);

    await tester.tap(find.text('Probar si me reconoce'));
    await tester.pumpAndSettle();

    expect(find.text('Te reconocí'), findsOneWidget);
    expect(find.textContaining('90 %'), findsOneWidget);
  });
}
