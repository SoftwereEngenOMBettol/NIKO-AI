import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niko_ai/utils/text_direction.dart';

void main() {
  test('Arabic text is right-to-left', () {
    expect(textDirectionFor('مرحبا نيكو'), TextDirection.rtl);
  });

  test('English and Turkish text are left-to-right', () {
    expect(textDirectionFor('Hello NIKO'), TextDirection.ltr);
    expect(textDirectionFor('Merhaba, nasılsın?'), TextDirection.ltr);
  });

  test('mixed text follows the first strong-script letter', () {
    expect(textDirectionFor('Hello مرحبا'), TextDirection.ltr);
    expect(textDirectionFor('مرحبا Hello'), TextDirection.rtl);
  });

  test('empty or punctuation-only text defaults to Arabic direction', () {
    expect(textDirectionFor(''), TextDirection.rtl);
    expect(textDirectionFor('...'), TextDirection.rtl);
  });
}
