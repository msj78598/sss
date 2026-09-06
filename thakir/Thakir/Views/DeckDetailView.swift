import SwiftUI

struct DeckDetailView: View {
    let deckID: UUID
    @Environment(Store.self) private var store
    @State private var showingScan = false
    @State private var showingEditor = false
    @State private var editingCard: Card?
    @State private var reviewing = false
    @State private var editingDeck = false

    private var deck: Deck? { store.deck(id: deckID) }

    var body: some View {
        if let deck {
            List {
                Section {
                    HStack(spacing: 12) {
                        StatPill(value: deck.cards.count, label: "بطاقة", color: .accentColor)
                        StatPill(value: deck.dueCount, label: "مستحقة", color: .orange)
                        StatPill(value: deck.masteredCount, label: "متقنة", color: .green)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    Button { showingScan = true } label: {
                        Label("مسح صفحة من الكتاب", systemImage: "doc.viewfinder")
                    }
                    Button { showingEditor = true } label: {
                        Label("إضافة بطاقة يدويًا", systemImage: "plus.rectangle.on.rectangle")
                    }
                    Button { reviewing = true } label: {
                        Label(deck.dueCount > 0 ? "ابدأ المراجعة (\(deck.dueCount))" : "تدريب حر", systemImage: "play.fill")
                    }
                    .disabled(deck.cards.isEmpty)
                }
                Section("البطاقات") {
                    if deck.cards.isEmpty {
                        Text("لا توجد بطاقات بعد. صوّر صفحة أو أضف بطاقة.").foregroundStyle(.secondary)
                    }
                    ForEach(deck.cards) { card in
                        Button { editingCard = card } label: { CardRow(card: card) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { deck.cards[$0] }.forEach { store.deleteCard($0, from: deckID) }
                    }
                }
            }
            .navigationTitle("\(deck.emoji) \(deck.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("تعديل") { editingDeck = true }
                }
            }
            .fullScreenCover(isPresented: $showingScan) { ScanFlowView(deckID: deckID) }
            .sheet(isPresented: $showingEditor) { CardEditorView(deckID: deckID, card: nil) }
            .sheet(item: $editingCard) { card in CardEditorView(deckID: deckID, card: card) }
            .sheet(isPresented: $editingDeck) { DeckFormView(mode: .edit(deck)) }
            .fullScreenCover(isPresented: $reviewing) {
                ReviewSessionView(deckID: deckID, freePractice: deck.dueCount == 0)
            }
        } else {
            ContentUnavailableView("المجموعة غير موجودة", systemImage: "questionmark.folder")
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct CardRow: View {
    let card: Card
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.front).font(.body).lineLimit(2)
            Text(card.back).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: card.isNew ? "sparkles" : (card.isDue ? "clock" : "checkmark.circle"))
                Text(card.isNew ? "جديدة" : (card.isDue ? "مستحقة" : "بعد \(card.interval) يوم"))
            }
            .font(.caption2).foregroundStyle(card.isDue ? .orange : .secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct CardEditorView: View {
    let deckID: UUID
    let card: Card?
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("الوجه (السؤال أو المصطلح)") {
                    TextField("اكتب السؤال", text: $front, axis: .vertical).lineLimit(2...5)
                }
                Section("الخلف (الإجابة أو التعريف)") {
                    TextField("اكتب الإجابة", text: $back, axis: .vertical).lineLimit(2...6)
                }
            }
            .navigationTitle(card == nil ? "بطاقة جديدة" : "تعديل البطاقة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty || back.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if let card { front = card.front; back = card.back } }
        }
    }

    private func save() {
        let f = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = back.trimmingCharacters(in: .whitespacesAndNewlines)
        if var existing = card {
            existing.front = f; existing.back = b
            store.update(existing, in: deckID)
        } else {
            store.addCards([Card(front: f, back: b)], to: deckID)
        }
        dismiss()
    }
}
