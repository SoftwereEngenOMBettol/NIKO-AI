# NIKO Local AI Backend

خادم محلي يربط تطبيق NIKO بنموذج لغوي يعمل على كمبيوتر المستخدم عبر Ollama. لا يحتاج إلى مفتاح API أو اشتراك مدفوع، لكنه يتطلب تنزيل نموذج وقد يكون أبطأ على CPU.

## المتطلبات
- Python 3.11 أو أحدث.
- Ollama مثبت ويعمل.
- النموذج الافتراضي: `qwen2.5:3b`، ونحتاج إلى اختبار جودة اللهجات عملياً.

## تشغيله على Windows

من مجلد المستودع:

```powershell
cd backend
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

ثبّت Ollama، ثم:

```powershell
ollama pull qwen2.5:3b
ollama run qwen2.5:3b
```

بعد ظهور رد من النموذج يمكنك إنهاء جلسة المحادثة؛ إذا لم يعمل Ollama في الخلفية شغّل `ollama serve` في نافذة مستقلة.

في نافذة PowerShell أخرى:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

تحقق من `http://127.0.0.1:8000/health`. يجب أن تكون `model_available: true`.

## اختبار المحرك مباشرة

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/v1/chat -ContentType "application/json" -Body '{"message":"هلا نيكو، وش عاصمة عُمان؟","language":"automatic"}'
```

## ربط Android Emulator

المحاكي يصل إلى الكمبيوتر المضيف عبر `10.0.2.2`:

```powershell
cd mobile
flutter run -d emulator-5554 --dart-define=NIKO_API_BASE_URL=http://10.0.2.2:8000
```

إذا منع Android الاتصال عبر HTTP أثناء التطوير، أضف `android:usesCleartextTraffic="true"` إلى وسم `<application>` في `mobile/android/app/src/main/AndroidManifest.xml`. هذا استثناء تطوير محلي فقط؛ لا تستخدم HTTP في إصدار إنتاجي.

## ربط iPhone لاحقاً
يجب أن يكون الكمبيوتر وiPhone على شبكة Wi-Fi نفسها، ويُستخدم عنوان LAN للكمبيوتر بدلاً من `10.0.2.2`. يلزم إعداد Local Network وقيود ATS في مشروع iOS عند اعتماد هذا المسار. لا تفتح المنفذ 8000 على الإنترنت العام.

## واجهات API
- `GET /health`: حالة API وتوفر النموذج.
- `POST /v1/chat`: يستقبل `message` و`language` ويعيد `reply` وبيانات المحرك.

## حدود النسخة الحالية
- الاستدلال محلي على الكمبيوتر؛ ليس نموذجاً مدمجاً داخل iPhone أو خدمة سحابية.
- لا توجد ذاكرة محادثة متعددة الأدوار على الخادم بعد؛ كل طلب يرسل رسالة واحدة.
- اكتشاف اللغة واللهجة يعتمد على النموذج ويحتاج إلى اختبارات واقعية.
- لا توجد مصادقة على API المحلي؛ شغّله على شبكة موثوقة فقط ولا تعرضه للإنترنت.
