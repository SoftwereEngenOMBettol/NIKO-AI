# فهرس مواصفات NIKO

هذا الفهرس يجمع مراجع المنتج والمعمارية والاختبارات. **وجود المواصفات لا يعني اكتمال التنفيذ.** الحالة الحقيقية لكل ميزة يجب أن تظهر في مصفوفة الميزات ونتائج CI واختبارات iPhone الفعلية.

## اتجاه المنتج

- [مواصفات المنتج](../PRODUCT_SPEC.md)
- [مواصفات التكافؤ مع Tab](../TAB_AI_PARITY_SPEC.md)
- [المعمارية](../ARCHITECTURE.md)
- [خارطة الطريق](../ROADMAP.md)
- [نطاق النسخة الأولى](MVP_SCOPE.md)
- [مصفوفة الميزات](FEATURE_MATRIX.md)
- [استراتيجية المنصات](PLATFORM_STRATEGY.md)
- [قرارات المنتج](DECISIONS.md)

## الصوت واللغات

- [الصوت المباشر على iPhone دون Siri](IOS_HANDS_FREE_VOICE.md)
- [اللغات واللهجات والحوار والصوت](VOICE_LANGUAGE_AND_DIALOGUE_SPEC.md)

## الذكاء الاصطناعي والمهارات والوسائط

- [توجيه مزودي النماذج وتقييمهم](MODEL_PROVIDER_ROUTING_SPEC.md)
- [استوديو الصور والفيديو والصوت](MEDIA_CREATION_STUDIO_SPEC.md)
- [المستندات والملفات والإنتاجية](DOCUMENTS_AND_PRODUCTIVITY_SPEC.md)
- [المهام الشخصية والتذكيرات والتقويم](PERSONAL_TASKS_AND_REMINDERS_SPEC.md)
- [تنفيذ المهارات والمهام والموافقات](SKILL_EXECUTION_AND_APPROVAL_SPEC.md)
- [الذاكرة والبحث والتكاملات الرسمية](MEMORY_RESEARCH_INTEGRATIONS_SPEC.md)

## الأمان والخصوصية

- [معمارية الخصوصية والعزل متعدد المستخدمين](SECURITY_PRIVACY_MULTI_TENANT.md)
- [نتائج المراجعة الأمنية والمتابعة](SECURITY_REVIEW_FINDINGS.md)

## قواعد قبول أي ميزة

1. تحديد الحالة: planned / scaffolded / implemented / tested / production-ready.
2. إضافة اختبارات آلية لكل تغيير.
3. إثبات التشغيل end-to-end قبل إعلان الإنجاز.
4. اختبار العزل بين مستخدمين لكل مورد خاص.
5. توثيق حدود iOS والأذونات والتكلفة وسياسة البيانات.
6. لا Siri ولا App Intents ولا Siri Shortcuts ولا Siri handoff.
7. لا مفاتيح أو أسرار داخل Flutter أو GitHub.
8. لا تشغيل لخدمة مدفوعة أو اشتراك دون موافقة صريحة.
9. لا دمج إلى `main` قبل اجتياز بوابات الأمان والمنتج وموافقة صاحب المشروع.
