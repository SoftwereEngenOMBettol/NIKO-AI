# بيئة تطوير NIKO على Windows

## وضع المشروع الحالي
يتوفر للمشروع كمبيوتر Windows مع VS Code وGitHub. لذلك يمكن تنفيذ التطوير الأولي واختبارات Android على Windows، مع الاحتفاظ بهدف دعم iOS وAndroid.

## ما يمكن إنجازه على Windows
- تثبيت Flutter SDK وDart.
- تطوير واجهة التطبيق في VS Code.
- تشغيل تطبيق Flutter على Android Emulator أو هاتف Android فعلي.
- تشغيل اختبارات Dart/Flutter والتحقق من الكود.
- تطوير واختبار خدمات Backend محلية عند الحاجة.
- إدارة المستودع والإصدارات عبر Git وGitHub.

## ما لا يتيحه Windows وحده
- لا يمكن تشغيل iOS Simulator أو تنفيذ بناء iOS المحلي باستخدام Xcode على Windows.
- بناء وتوقيع نسخة iOS الرسمية يتطلبان macOS وXcode في مرحلة إصدار iOS.
- وجود iPhone لا يزيل هذا القيد؛ يمكننا تطوير معظم التطبيق على Windows، ثم ترتيب وصول إلى بيئة Mac عند الحاجة لاختبار وبناء iOS.

## خطوات إعداد البيئة — لا تبدأ قبل مراجعة حالة الجهاز
1. التحقق مما إذا كان Git مثبتاً.
2. تثبيت Flutter SDK من المصدر الرسمي أو عبر مسار VS Code الموصى به.
3. تثبيت إضافتي Flutter وDart في VS Code.
4. تثبيت Android Studio فقط للحصول على Android SDK وEmulator وأدوات البناء اللازمة.
5. تشغيل `flutter doctor -v` ومراجعة النتائج.
6. إعداد Android Emulator أو توصيل جهاز Android مع تفعيل USB debugging.
7. تشغيل `flutter devices` للتأكد من اكتشاف جهاز الاختبار.

## الروابط الرسمية
- Flutter install: https://docs.flutter.dev/install
- Flutter with VS Code: https://docs.flutter.dev/install/with-vs-code
- Flutter Android setup: https://docs.flutter.dev/platform-integration/android/setup
- Flutter VS Code: https://docs.flutter.dev/tools/vs-code
- iOS setup: https://docs.flutter.dev/platform-integration/ios/setup

## سياسة التثبيت
- استخدم الأدوات الرسمية والمجانية.
- لا تثبت أدوات أو إضافات غير ضرورية.
- لا تضع مفاتيح API أو كلمات مرور أو بيانات شخصية في GitHub.
- لا تبدأ بتنزيل نماذج ذكاء اصطناعي كبيرة قبل معرفة مواصفات RAM والمعالج ومساحة التخزين.
- لا نفترض أن تشغيل نموذج محلي قوي على الكمبيوتر يعني أنه سيعمل جيداً على الهاتف.

## الخطوة التالية
اجمع مواصفات الكمبيوتر (المعالج، RAM، مساحة التخزين، وكرت الشاشة إن وجد)، ثم حدد إن كان مناسباً للمحاكيات وتجارب النماذج المحلية. لا تثبت أو تغيّر إعدادات النظام قبل موافقة صاحب المشروع.
