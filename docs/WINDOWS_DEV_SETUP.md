# بيئة تطوير NIKO على Windows — iPhone أولاً

## مواصفات جهاز التطوير المتاح
| المكوّن | المواصفات |
|---|---|
| الجهاز | Huawei MateBook 13s |
| المعالج | Intel Core i7-11370H الجيل 11، بسرعة 3.30 GHz |
| الذاكرة | 16 GB RAM |
| الرسوميات | Intel Iris Xe Graphics مدمج |
| التخزين | 477 GB إجمالي، والمساحة المتاحة وقت التوثيق نحو 202 GB |

## تقييم الجهاز
**مناسب لتطوير Flutter وDart وBackend وإجراء الاختبارات العامة.** لا يشغّل Xcode أو iOS Simulator لأنه يعمل بنظام Windows.

- تطوير Flutter وDart وVS Code: مناسب.
- تطوير Backend محلي وتجارب API: مناسب.
- Android Emulator: متاح للاختبارات الثانوية فقط عند الحاجة.
- نماذج الذكاء المحلية: نبدأ بنماذج صغيرة وتجارب CPU؛ لا نعتمد على تشغيل نماذج كبيرة.
- لا نبني الخطة على وجود NVIDIA أو CUDA.

## ما يمكن إنجازه على Windows
- تطوير واجهة Flutter والمنطق المشترك.
- تشغيل اختبارات Dart/Flutter والتحليل.
- إدارة Git وGitHub.
- تطوير Backend محلياً.
- مراجعة التغييرات ورفعها إلى GitHub.
- تشغيل Android Emulator كاختبار ثانوي عند الحاجة.

## ما لا يتيحه Windows وحده
- لا يمكن تشغيل iOS Simulator أو بناء iOS باستخدام Xcode على Windows.
- لا يمكن توقيع تطبيق iOS النهائي محلياً عبر Xcode.
- وجود iPhone لا يزيل هذا القيد.
- يمكن لـ GitHub Actions على macOS إجراء بناء iOS Simulator دون توقيع، لكن هذا لا ينتج IPA قابلاً للتثبيت على iPhone.
- لاختبار iPhone حقيقي أو إصدار نسخة قابلة للتثبيت نحتاج macOS/Xcode وإعداد التوقيع المناسب، عبر Mac متاح أو خدمة بناء macOS موثوقة.

## سير العمل المعتمد
1. تطوير الميزات المشتركة في Flutter على Windows.
2. تشغيل `flutter analyze` و`flutter test` محلياً.
3. رفع التغييرات إلى فرع `main` وفق سياسة المشروع.
4. GitHub Actions على macOS ينفذ بناء iOS Simulator للتحقق من التوافق.
5. عند جاهزية مرحلة اختبار الجهاز، نستخدم Mac/Xcode ونجهز التوقيع لتثبيت التطبيق على iPhone.
6. لا نبدأ تحسينات Android الخاصة إلا بعد استقرار أساس iOS.

## أوامر التطوير المحلي
من مجلد المشروع:
```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

يمكن تشغيل التطبيق على Android Emulator الموجود لديك كاختبار مؤقت، لكنه ليس معيار قبول المنتج الأساسي.

## الروابط الرسمية
- Flutter install: https://docs.flutter.dev/install
- Flutter with VS Code: https://docs.flutter.dev/install/with-vs-code
- Flutter iOS setup: https://docs.flutter.dev/platform-integration/ios/setup
- Flutter VS Code: https://docs.flutter.dev/tools/vs-code
- Apple Xcode: https://developer.apple.com/xcode/

## سياسة التثبيت
- استخدم الأدوات الرسمية والمجانية قدر الإمكان.
- لا تثبت أدوات إضافية غير ضرورية.
- لا تضع مفاتيح API أو كلمات مرور أو بيانات شخصية في GitHub.
- لا تفترض أن خدمة macOS السحابية أو توقيع iOS أو النشر مجانية.
- راجع التكلفة وشروط الخدمة قبل استخدام أي Mac سحابي.

## الخطوة التالية
إضافة مشروع iOS والتحقق من نجاح بناء Simulator في macOS CI، ثم تجهيز اختبار على iPhone حقيقي عند توفر بيئة Mac والتوقيع.