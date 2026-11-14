import 'package:flutter/widgets.dart';

/// Chooses the writing direction from the first Arabic or Latin-script letter.
/// Arabic is the default for an empty or punctuation-only composer.
TextDirection textDirectionFor(String text) {
  final arabic = RegExp(r'[\\u0600-\\u06FF\\u0750-\\u077F\\u08A0-\\u08FF]')
      .firstMatch(text);
  final latin = RegExp(r'[A-Za-z\\u00C0-\\u024F]').firstMatch(text);

  if (arabic == null && latin == null) return TextDirection.rtl;
  if (arabic == null) return TextDirection.ltr;
  if (latin == null) return TextDirection.rtl;
  return arabic.start < latin.start ? TextDirection.rtl : TextDirection.ltr;
}
