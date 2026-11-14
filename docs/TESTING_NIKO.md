# اختبار تطبيق NIKO

## ما يمكن اختباره الآن

هذه نسخة أولية من الواجهة والصوت، وليست مساعداً ذكياً متصلاً بعد:
- المحادثة تستخدم `DemoNikoChatService` وتعرض ردوداً تجريبية.
- زر الميكروفون يحوّل الكلام إلى نص في حقل الكتابة، ولا يرسل الرسالة تلقائياً.
- زر السماعة ينطق رد نيكو باستخدام أصوات النظام المتاحة.
- دعم اللهجات والمحادثة الذكية والذاكرة الدلالية لم تُنفّذ بعد.

## فحوصات سريعة على Windows

من PowerShell:

```powershell
cd "C:\Users\dnanmol\OneDrive - University of Technology and Applied Sciences\Desktop\NIKO-AI\mobile"
flutter pub get
flutter analyze
flutter test
flutter devices
```

هذه الأوامر تتحقق من التبعيات والتحليل والاختبارات. إذا ظهر جهاز Android Emulator في `flutter devices`، يمكن تشغيل نسخة Android عليه كاختبار ثانوي:

```powershell
flutter run -d <device-id>
```

استبدل `<device-id>` بالمعرّف الذي يظهر في قائمة الأجهزة. هذا لا يختبر iOS.

## اختبار iPhone 13 فعلياً

لا يمكن تثبيت ملف iOS Simulator الناتج من GitHub Actions على iPhone، كما لا يستطيع Windows تشغيل Xcode أو توقيع تطبيق iOS. لاختبار الميكروفون والصوت على iPhone نحتاج جهاز Mac مع Xcode:

1. استنساخ المستودع على جهاز Mac وتثبيت Flutter وXcode.
2. من مجلد `mobile` توليد ملفات iOS إن لم يكن مجلد `ios` موجوداً:
   ```bash
   flutter create --platforms=ios --org com.nikoai --project-name niko_ai .
   ```
3. إضافة مفاتيح الخصوصية التالية إلى `ios/Runner/Info.plist`:
   - `NSSpeechRecognitionUsageDescription`
   - `NSMicrophoneUsageDescription`
4. تشغيل `flutter pub get` ثم فتح `ios/Runner.xcworkspace` في Xcode.
5. اختيار Runner > Signing & Capabilities، وتحديد Team وBundle Identifier صالحين، وتفعيل Automatically manage signing.
6. توصيل iPhone 13، الوثوق بالـ Mac عند الطلب، اختيار الجهاز في Xcode أو `flutter devices`، ثم تشغيل:
   ```bash
   flutter run -d <iphone-device-id>
   ```

التثبيت المباشر للتطوير يتطلب إعداد توقيع Apple صالحاً. التوزيع عبر TestFlight يتطلب عضوية Apple Developer Program.

## سيناريو اختبار على iPhone

1. افتح NIKO وتأكد من ظهور الواجهة العربية واتجاه RTL.
2. اضغط الميكروفون ووافق على صلاحيات الميكروفون والتعرف على الكلام.
3. قل: «مرحبا نيكو، كيف حالك؟» وتأكد من ظهور النص في حقل الكتابة دون إرساله.
4. أرسل الرسالة وتأكد من ظهور رد تجريبي.
5. اضغط زر السماعة أسفل رد نيكو وتحقق من سماع الصوت.
6. كرر الاختبار بالإنجليزية والتركية، وتحقق من اللغة والصوت المتاحين على الجهاز.
7. جرّب إيقاف الاستماع، ورفض الصلاحية، وإعادة فتح التطبيق، وتأكد من عرض رسائل واضحة وعدم تعطل الواجهة.

## ملف المحاكي من GitHub Actions

التشغيل الناجح يرفع artifact باسم `niko-ai-ios-simulator` لمدة 14 يوماً. يمكن تنزيله من صفحة Actions > التشغيل الناجح > Artifacts، لكنه مخصص لمحاكي iOS على macOS فقط، وليس ملف IPA لجهاز iPhone.
