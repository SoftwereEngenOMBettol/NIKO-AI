import 'package:flutter/widgets.dart';

/// Chooses writing direction from the first Arabic or Latin-script letter.
/// Arabic is the default for empty or punctuation-only text.
TextDirection textDirectionFor(String text) {
  for (final rune in text.runes) {
    final isArabic = (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF);
    if (isArabic) return TextDirection.rtl;

    final isLatin = (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F);
    if (isLatin) return TextDirection.ltr;
  }

  return TextDirection.rtl;
}
