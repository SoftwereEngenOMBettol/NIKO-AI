import 'package:flutter_test/flutter_test.dart';
import 'package:niko_ai/main.dart';

void main() {
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
}
