import SwiftUI
import PhotosUI

/// مسار «صفحة → نص → بطاقات»: كاميرا أو صورة أو لصق، ثم مراجعة البطاقات المقترحة قبل الحفظ.
struct ScanFlowView: View {
    let deckID: UUID
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .pick
    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pastedText = ""
    @State private var showingPaste = false
    @State private var drafts: [DraftCard] = []
    @State private var errorMessage: String?

    enum Stage { case pick, processing, review }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick: pickView
                case .processing: ProgressView("جارٍ استخراج النص…").controlSize(.large)
                case .review: reviewView
                }
            }
            .navigationTitle("توليد بطاقات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } }
                if stage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("إضافة \(selectedCount)") { saveDrafts() }.disabled(selectedCount == 0)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                DocumentScanner { images in Task { await process(images: images) } }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPaste) { pasteSheet }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await process(images: [image])
                    }
                    photoItem = nil
                }
            }
            .alert("تعذّر الاستخراج", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("حسنًا") {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    // MARK: - المرحلة الأولى

    private var pickView: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64)).foregroundStyle(Color.accentColor)
                .padding(.top, 30)
            Text("صوّر صفحة من الكتاب أو الملزمة، وسيحوّل ذاكِر النص إلى بطاقات مراجعة على جهازك مباشرة.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)

            VStack(spacing: 12) {
                if DocumentScanner.isSupported {
                    BigButton(title: "تصوير بالكاميرا", icon: "camera.fill") { showingCamera = true }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    BigButtonLabel(title: "اختيار صورة من الصور", icon: "photo.on.rectangle")
                }
                BigButton(title: "لصق نص", icon: "doc.on.clipboard", secondary: true) { showingPaste = true }
            }
            .padding(.horizontal)

            if !OCRService.supportsArabic {
                Label("هذا الجهاز لا يدعم التعرّف على النص العربي في الصور. يمكنك لصق النص مباشرة.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
            Spacer()
        }
    }

    private var pasteSheet: some View {
        NavigationStack {
            TextEditor(text: $pastedText)
                .padding()
                .navigationTitle("لصق النص")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { showingPaste = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("استخراج") {
                            showingPaste = false
                            buildDrafts(from: pastedText)
                        }
                        .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }

    // MARK: - المرحلة الثالثة

    private var reviewView: some View {
        List {
            Section {
                Text("راجع البطاقات المقترحة، وعدّل ما تشاء، ثم اضغط «إضافة».")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach($drafts) { $draft in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("", isOn: $draft.selected).labelsHidden()
                        Text(kindLabel(draft.kind)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    TextField("الوجه", text: $draft.front, axis: .vertical).font(.body)
                    Divider()
                    TextField("الخلف", text: $draft.back, axis: .vertical).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .opacity(draft.selected ? 1 : 0.45)
            }
            .onDelete { drafts.remove(atOffsets: $0) }
        }
        .overlay {
            if drafts.isEmpty {
                ContentUnavailableView("لم نجد نصًا مناسبًا", systemImage: "text.magnifyingglass",
                                       description: Text("جرّب صورة أوضح، أو الصق النص يدويًا."))
            }
        }
    }

    // MARK: - المنطق

    private var selectedCount: Int { drafts.filter(\.selected).count }

    private func kindLabel(_ kind: DraftCard.Kind) -> String {
        switch kind {
        case .pair: return "مصطلح وتعريف"
        case .question: return "سؤال وجواب"
        case .cloze: return "أكمل الفراغ"
        }
    }

    private func process(images: [UIImage]) async {
        stage = .processing
        var text = ""
        for image in images {
            do {
                text += try await OCRService.recognize(image) + "\n"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        buildDrafts(from: text)
    }

    private func buildDrafts(from text: String) {
        drafts = CardExtractor.extract(from: text)
        stage = .review
    }

    private func saveDrafts() {
        let cards = drafts.filter(\.selected).map { Card(front: $0.front, back: $0.back) }
        store.addCards(cards, to: deckID)
        dismiss()
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    var secondary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { BigButtonLabel(title: title, icon: icon, secondary: secondary) }
    }
}

struct BigButtonLabel: View {
    let title: String
    let icon: String
    var secondary = false
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(secondary ? Color.accentColor.opacity(0.12) : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(secondary ? Color.accentColor : .white)
    }
}
