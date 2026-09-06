import Foundation
import Observation

/// مخزن البيانات: مجموعات وبطاقات وسجل المراجعات، محفوظ محليًا بصيغة JSON.
@Observable
final class Store {
    var decks: [Deck] = []
    var reviewLog: [Date] = []          // وقت كل مراجعة، للإحصاءات والسلسلة اليومية
    private(set) var isLoaded = false

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Thakir", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("library.json")
        }
        load()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var decks: [Deck]
        var reviewLog: [Date]
    }

    func load() {
        defer { isLoaded = true }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snap = try? decoder.decode(Snapshot.self, from: data) {
            decks = snap.decks
            reviewLog = snap.reviewLog
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(Snapshot(decks: decks, reviewLog: reviewLog)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Decks

    @discardableResult
    func addDeck(name: String, emoji: String) -> Deck {
        let deck = Deck(name: name, emoji: emoji)
        decks.insert(deck, at: 0)
        save()
        return deck
    }

    func deleteDeck(_ deck: Deck) {
        decks.removeAll { $0.id == deck.id }
        save()
    }

    func rename(_ deck: Deck, name: String, emoji: String) {
        guard let i = index(of: deck.id) else { return }
        decks[i].name = name
        decks[i].emoji = emoji
        save()
    }

    func deck(id: UUID) -> Deck? { decks.first { $0.id == id } }
    private func index(of id: UUID) -> Int? { decks.firstIndex { $0.id == id } }

    // MARK: - Cards

    func addCards(_ cards: [Card], to deckID: UUID) {
        guard let i = index(of: deckID) else { return }
        decks[i].cards.append(contentsOf: cards)
        save()
    }

    func update(_ card: Card, in deckID: UUID) {
        guard let i = index(of: deckID), let j = decks[i].cards.firstIndex(where: { $0.id == card.id }) else { return }
        decks[i].cards[j] = card
        save()
    }

    func deleteCard(_ card: Card, from deckID: UUID) {
        guard let i = index(of: deckID) else { return }
        decks[i].cards.removeAll { $0.id == card.id }
        save()
    }

    /// يسجّل نتيجة مراجعة ويعيد جدولة البطاقة.
    func review(_ card: Card, in deckID: UUID, grade: ReviewGrade) {
        let updated = Scheduler.schedule(card, grade: grade)
        update(updated, in: deckID)
        reviewLog.append(Date())
        save()
    }

    // MARK: - Queries

    func dueCards(in deckID: UUID? = nil, limit: Int = 50) -> [(deckID: UUID, card: Card)] {
        let source = deckID.map { id in decks.filter { $0.id == id } } ?? decks
        let due = source.flatMap { deck in deck.cards.filter(\.isDue).map { (deckID: deck.id, card: $0) } }
        return Array(due.sorted { $0.card.dueDate < $1.card.dueDate }.prefix(limit))
    }

    var totalCards: Int { decks.reduce(0) { $0 + $1.cards.count } }
    var totalDue: Int { decks.reduce(0) { $0 + $1.dueCount } }

    func reviewsOn(_ day: Date) -> Int {
        let cal = Calendar.current
        return reviewLog.filter { cal.isDate($0, inSameDayAs: day) }.count
    }

    /// عدد الأيام المتتالية التي تمت فيها مراجعة حتى اليوم.
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var count = 0
        if reviewsOn(day) == 0 {
            guard let y = cal.date(byAdding: .day, value: -1, to: day), reviewsOn(y) > 0 else { return 0 }
            day = y
        }
        while reviewsOn(day) > 0 {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    struct DayCount: Identifiable {
        let day: Date
        let count: Int
        var id: Date { day }
    }

    /// مراجعات آخر سبعة أيام (الأقدم أولًا).
    var lastWeek: [DayCount] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { return nil }
            return DayCount(day: d, count: reviewsOn(d))
        }
    }

    // MARK: - Sample content

    func addSampleDeckIfEmpty() {
        guard decks.isEmpty else { return }
        let deck = addDeck(name: "مثال: علوم", emoji: "🔬")
        let cards = [
            Card(front: "ما هي نسبة النيتروجين في الهواء؟", back: "78%"),
            Card(front: "الأوزون الأرضي", back: "غاز يتكوّن بتفاعل الملوّثات مع ضوء الشمس ويضرّ الرئتين"),
            Card(front: "تُقاس جودة الهواء بمؤشر ______", back: "AQI"),
        ]
        addCards(cards, to: deck.id)
    }
}
