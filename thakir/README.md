# ذاكِر (Thakir) — iOS

تطبيق SwiftUI يحوّل صفحات الكتب إلى بطاقات مراجعة ويجدولها بخوارزمية التكرار المتباعد (SM-2).
كل المعالجة على الجهاز: التعرّف على النص عبر Vision، والتخزين محلي بصيغة JSON.

- الحد الأدنى: iOS 17، آيفون فقط.
- المشروع يُولَّد من `project.yml` عبر XcodeGen: `brew install xcodegen && xcodegen generate`.
- الاختبارات: `xcodebuild test -project Thakir.xcodeproj -scheme Thakir -destination 'platform=iOS Simulator,name=iPhone 16'`.
- البناء والاختبار الآلي: `.github/workflows/ios-ci.yml` على macOS.
- سياسة الخصوصية والدعم: `docs/`.
