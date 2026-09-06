import SwiftUI

struct DeckListView: View {
    @Environment(Store.self) private var store
    @State private var showingNewDeck = false

    var body: some View {
        NavigationStack {
            Group {
                if store.decks.isEmpty {
                    ContentUnavailableView("لا توجد مجموعات بعد", systemImage: "rectangle.stack.badge.plus",
                                           description: Text("أنشئ مجموعة لمادة أو فصل، ثم صوّر صفحة من الكتاب لتوليد البطاقات."))
                } else {
                    List {
                        ForEach(store.decks) { deck in
                            NavigationLink(value: deck.id) {
                                DeckRow(deck: deck)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { store.decks[$0] }.forEach(store.deleteDeck)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("ذاكِر")
            .navigationDestination(for: UUID.self) { id in
                DeckDetailView(deckID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewDeck = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("مجموعة جديدة")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("الإعدادات")
                }
            }
            .sheet(isPresented: $showingNewDeck) {
                DeckFormView(mode: .create)
            }
        }
    }
}

struct DeckRow: View {
    let deck: Deck

    var body: some View {
        HStack(spacing: 14) {
            Text(deck.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name).font(.headline)
                Text("\(deck.cards.count) بطاقة · \(deck.masteredCount) متقنة")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if deck.dueCount > 0 {
                Text("\(deck.dueCount)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange, in: Capsule())
                    .foregroundStyle(.white)
                    .accessibilityLabel("\(deck.dueCount) بطاقة مستحقة")
            }
        }
        .padding(.vertical, 4)
    }
}

struct DeckFormView: View {
    enum Mode { case create, edit(Deck) }
    let mode: Mode
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "📘"
    private let emojis = ["📘", "🔬", "🧬", "⚗️", "⚛️", "📐", "🌍", "🕌", "🗣️", "💻", "📖", "🧠"]

    var body: some View {
        NavigationStack {
            Form {
                Section("اسم المجموعة") {
                    TextField("مثال: أحياء – الفصل الثاني", text: $name)
                }
                Section("الرمز") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(emojis, id: \.self) { e in
                            Text(e).font(.system(size: 28))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(e == emoji ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { emoji = e }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "تعديل المجموعة" : "مجموعة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let deck) = mode { name = deck.name; emoji = deck.emoji }
            }
        }
    }

    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create: store.addDeck(name: trimmed, emoji: emoji)
        case .edit(let deck): store.rename(deck, name: trimmed, emoji: emoji)
        }
        dismiss()
    }
}
