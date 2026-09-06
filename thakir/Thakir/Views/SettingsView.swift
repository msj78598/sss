import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var confirmReset = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section("عن التطبيق") {
                LabeledContent("الإصدار", value: version)
                LabeledContent("التعرّف على العربية في الصور", value: OCRService.supportsArabic ? "مدعوم" : "غير مدعوم على هذا الجهاز")
                Text("ذاكِر يحوّل صفحات الكتب إلى بطاقات مراجعة، ويجدولها بخوارزمية التكرار المتباعد لتذكّرها لفترة أطول. كل بياناتك تبقى على جهازك.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("الخصوصية والدعم") {
                Link(destination: URL(string: "https://msj78598.github.io/sss/thakir/privacy")!) {
                    Label("سياسة الخصوصية", systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://msj78598.github.io/sss/thakir/support")!) {
                    Label("الدعم والتواصل", systemImage: "envelope")
                }
            }
            Section {
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("حذف كل البيانات", systemImage: "trash")
                }
            }
        }
        .navigationTitle("الإعدادات")
        .confirmationDialog("سيتم حذف كل المجموعات والبطاقات وسجل المراجعة نهائيًا.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("حذف الكل", role: .destructive) {
                store.decks.removeAll()
                store.reviewLog.removeAll()
                store.save()
            }
            Button("إلغاء", role: .cancel) {}
        }
    }
}
