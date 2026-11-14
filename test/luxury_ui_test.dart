import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/localization/app_translations.dart';
import 'package:pdf_reader/core/widgets/luxury_dialog.dart';
import 'package:pdf_reader/modules/pdf_tools/widgets/tool_empty_view.dart';

void main() {
  group('Luxury UI & Translations Verification', () {
    test('Document Editor labels contain no WPS branding', () {
      final translations = AppTranslations().keys;
      final enTitle = translations['en']?['tool_document_editor'] ?? '';
      final arTitle = translations['ar']?['tool_document_editor'] ?? '';

      expect(enTitle, equals('Document Editor'));
      expect(arTitle, equals('محرر المستندات'));
      expect(enTitle.toLowerCase(), isNot(contains('wps')));
      expect(arTitle.toLowerCase(), isNot(contains('wps')));
    });

    testWidgets('LuxuryDialog renders in RTL Dark Theme and handles actions',
        (WidgetTester tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            primaryColor: const Color(0xFF818CF8),
            scaffoldBackgroundColor: const Color(0xFF0B0F19),
            cardColor: const Color(0xFF151D30),
            dividerColor: const Color(0xFF22304D),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      dialogResult = await LuxuryDialog.show(
                        context,
                        title: 'ضغط PDF',
                        badgeText: 'قريبًا • أداة قيد التطوير',
                        badgeIcon: Icons.schedule_rounded,
                        icon: Icons.compress_rounded,
                        message: 'هذه الأداة قيد التطوير البرمجي حاليًا.',
                        highlightsTitle: 'ما الذي ستقدمه الأداة؟',
                        highlights: const [
                          LuxuryDialogHighlight(
                            icon: Icons.speed_rounded,
                            text: 'تقليص حجم الملف مع الحفاظ على الجودة',
                          ),
                        ],
                        primaryButtonText: 'حسنًا',
                        primaryButtonIcon: Icons.check_rounded,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('ضغط PDF'), findsOneWidget);
      expect(find.text('قريبًا • أداة قيد التطوير'), findsOneWidget);
      expect(find.text('ما الذي ستقدمه الأداة؟'), findsOneWidget);
      expect(find.text('تقليص حجم الملف مع الحفاظ على الجودة'), findsOneWidget);
      expect(find.text('حسنًا'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
      expect(find.text('ضغط PDF'), findsNothing);
    });

    testWidgets('LuxuryDialog compact destructive mode and validation flow',
        (WidgetTester tester) async {
      String? enteredName;
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4F46E5),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            dividerColor: const Color(0xFFE2E8F0),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      enteredName = await LuxuryDialog.showCustom<String>(
                        context,
                        builder: (dCtx) {
                          String? errorText;
                          return StatefulBuilder(
                            builder: (dCtx, setDialogState) => LuxuryDialog(
                              compact: true,
                              accentColor: const Color(0xFF16A34A),
                              icon: Icons.save_rounded,
                              title: 'حفظ باسم',
                              body: TextField(
                                controller: ctrl,
                                decoration: InputDecoration(
                                  hintText: 'اسم الملف',
                                  errorText: errorText,
                                ),
                              ),
                              secondaryButtonText: 'إلغاء',
                              primaryButtonText: 'حفظ',
                              closeOnPrimary: false,
                              onPrimaryPressed: () {
                                if (ctrl.text.trim().isEmpty) {
                                  setDialogState(() => errorText = 'مطلوب');
                                  return;
                                }
                                Navigator.of(dCtx).pop(ctrl.text.trim());
                              },
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('saveDialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('saveDialog'));
      await tester.pumpAndSettle();

      // Empty submit should validate and keep dialog open
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('مطلوب'), findsOneWidget);
      expect(find.text('حفظ باسم'), findsOneWidget);

      // Valid submit closes dialog with typed value
      await tester.enterText(find.byType(TextField), 'report_final');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(enteredName, equals('report_final'));
      expect(find.text('حفظ باسم'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LuxuryDialog Tool Guide mode opens tool on primary action',
        (WidgetTester tester) async {
      var openedTool = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            primaryColor: const Color(0xFF818CF8),
            cardColor: const Color(0xFF151D30),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      LuxuryDialog.show(
                        context,
                        icon: Icons.merge_type_rounded,
                        title: 'دمج PDF',
                        badgeText: 'متوفرة الآن • جاهزة للاستخدام',
                        badgeIcon: Icons.check_circle_rounded,
                        message: 'دمج عدة ملفات PDF في مستند واحد.',
                        highlightsTitle: 'كيف تستخدم الأداة:',
                        highlights: const [
                          LuxuryDialogHighlight(
                            icon: Icons.looks_one_rounded,
                            text: 'اختر ملفين PDF أو أكثر.',
                          ),
                        ],
                        secondaryButtonText: 'إغلاق',
                        primaryButtonText: 'فتح الأداة الآن',
                        primaryButtonIcon: Icons.arrow_forward_rounded,
                        onPrimaryPressed: () => openedTool = true,
                      );
                    },
                    child: const Text('guide'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('guide'));
      await tester.pumpAndSettle();
      expect(find.text('متوفرة الآن • جاهزة للاستخدام'), findsOneWidget);
      expect(find.text('كيف تستخدم الأداة:'), findsOneWidget);

      await tester.tap(find.text('فتح الأداة الآن'));
      await tester.pumpAndSettle();
      expect(openedTool, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LuxuryDialog showActions false works cleanly for pickers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    LuxuryDialog.showCustom(
                      context,
                      builder: (dCtx) => LuxuryDialog(
                        compact: true,
                        icon: Icons.translate_rounded,
                        title: 'Language',
                        showActions: false,
                        body: ListTile(
                          title: const Text('Arabic'),
                          onTap: () => Navigator.of(dCtx).pop(),
                        ),
                      ),
                    );
                  },
                  child: const Text('picker'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('picker'));
      await tester.pumpAndSettle();
      expect(find.text('Arabic'), findsOneWidget);
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('LuxuryDialog gradient resolver preserves red destructive hues', () {
      final (start, end) = LuxuryDialog.resolveGradientColors(
        ThemeData.light(),
        accentColor: Colors.redAccent,
      );
      // Red channel stays dominant (not shifted to purple/indigo)
      expect((start.r * 255).round(), greaterThan((start.b * 255).round()));
      expect((end.r * 255).round(), greaterThan((end.b * 255).round()));
    });

    testWidgets('ToolEmptyView renders themed gradient button and triggers onAction',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4F46E5),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ToolEmptyView(
                imagePath: 'assets/vector/missing_in_test.png',
                description: 'وصف تجريبي للأداة',
                actionLabel: 'اختر ملفات PDF',
                actionIcon: Icons.picture_as_pdf_rounded,
                onAction: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('وصف تجريبي للأداة'), findsOneWidget);
      expect(find.text('اختر ملفات PDF'), findsOneWidget);

      await tester.tap(find.text('اختر ملفات PDF'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
