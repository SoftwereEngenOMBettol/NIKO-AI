import 'package:flutter_test/flutter_test.dart';
import 'package:niko_ai/services/niko_speech_output_service.dart';

void main() {
  test('Arabic text selects an Arabic system voice locale', () {
    expect(speechLocaleForText('مرحبا بك'), 'ar-SA');
  });

  test('Turkish-specific characters select a Turkish system voice locale', () {
    expect(speechLocaleForText('Merhaba, nasılsın?'), 'tr-TR');
  });

  test('Latin text defaults to English voice locale', () {
    expect(speechLocaleForText('Hello, how are you?'), 'en-US');
  });
}
