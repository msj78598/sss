# خطوات النشر إلى App Store — تطبيق ذاكِر

النشر آلي بالكامل عبر GitHub Actions بتوقيع سحابي من Apple (لا حاجة لشهادات محلية ولا لجهاز Mac).
المطلوب منك مرة واحدة فقط:

## 1) مفتاح App Store Connect API (دور Admin)
1. افتح https://appstoreconnect.apple.com ← **Users and Access** ← تبويب **Integrations** ← **App Store Connect API**.
2. اضغط **+** وأنشئ مفتاحًا باسم `github-ci` وبالدور **Admin** (الدور اللازم للتوقيع السحابي).
3. حمّل ملف `AuthKey_XXXXXXXXXX.p8` (يُحمَّل مرة واحدة فقط) واحفظ **Key ID** و**Issuer ID** الظاهرين في الصفحة.

## 2) رقم الفريق (Team ID)
https://developer.apple.com/account ← **Membership details** ← **Team ID** (10 خانات).

## 3) الأسرار في GitHub
في المستودع: **Settings** ← **Secrets and variables** ← **Actions** ← **New repository secret**:

| الاسم | القيمة |
|---|---|
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | محتوى ملف p8 كاملًا (افتحه بمحرر نصوص وانسخ كل شيء بما فيه أسطر BEGIN/END) |
| `APPLE_TEAM_ID` | Team ID |

## 4) إنشاء سجل التطبيق في App Store Connect
بعد أول تشغيل ناجح لخطوة «Register bundle id» (أو يدويًا من https://developer.apple.com/account/resources/identifiers):
1. App Store Connect ← **Apps** ← **+** ← **New App**.
2. Platform: iOS، Name: **ذاكِر**، Primary Language: Arabic، Bundle ID: `com.msj.thakir`، SKU: `thakir-ios`.

## 5) الرفع إلى TestFlight
GitHub ← **Actions** ← **iOS Release (Thakir → TestFlight)** ← **Run workflow** ← أدخل رقم الإصدار (1.0.0) ← Run.
بعد نحو 15 دقيقة يظهر الإصدار في App Store Connect ← TestFlight.

## 6) الإرسال للمراجعة
في App Store Connect ← التطبيق ← **1.0 Prepare for Submission**: يُستخدم المحتوى الجاهز في مجلد `metadata/` (الوصف، الكلمات المفتاحية، سياسة الخصوصية، لقطات الشاشة)، ثم اختر الإصدار المرفوع واضغط **Add for Review** ثم **Submit**.
