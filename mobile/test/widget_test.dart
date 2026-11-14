// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niko_ai/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('NIKO opens with Arabic welcome and composer', (tester) async {
    await tester.pumpWidget(const NikoApp());

    expect(find.text('NIKO AI'), findsOneWidget);
    expect(find.text('هلا، أنا نيكو. موجود معك — وش حاب نسوي اليوم؟'), findsOneWidget);
    expect(find.text('اكتب لنيكو...'), findsOneWidget);
  });

  testWidgets('sending a message adds it to the conversation', (tester) async {
    await tester.pumpWidget(const NikoApp());

    await tester.enterText(find.byType(EditableText), 'مرحبا نيكو');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('مرحبا نيكو'), findsOneWidget);
  });

  testWidgets('composer switches direction for English and Arabic input', (tester) async {
    await tester.pumpWidget(const NikoApp());

    await tester.enterText(find.byType(EditableText), 'Hello NIKO');
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).textDirection,
      TextDirection.ltr,
    );

    await tester.enterText(find.byType(EditableText), 'مرحبا نيكو');
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).textDirection,
      TextDirection.rtl,
    );
  });
}
