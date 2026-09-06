import Foundation

/// مجموعة بطاقات (مادة أو فصل).
struct Deck: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "📘"
    var createdAt: Date = Date()
    var cards: [Card] = []

    var dueCount: Int { cards.filter { $0.isDue }.count }
    var masteredCount: Int { cards.filter { $0.interval >= 21 }.count }
}

/// بطاقة مراجعة بحالة جدولة SM-2.
struct Card: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var front: String
    var back: String
    var createdAt: Date = Date()
    var easeFactor: Double = 2.5
    var interval: Int = 0          // بالأيام
    var repetitions: Int = 0
    var dueDate: Date = Date()
    var lastReviewed: Date? = nil
    var reviewCount: Int = 0
    var lapses: Int = 0

    var isDue: Bool { dueDate <= Date() }
    var isNew: Bool { reviewCount == 0 }
}

/// تقييم المستخدم بعد كشف الإجابة.
enum ReviewGrade: Int, CaseIterable, Identifiable {
    case again = 0, hard = 3, good = 4, easy = 5
    var id: Int { rawValue }
}

/// خوارزمية التكرار المتباعد SM-2 مع تعديلات بسيطة للنسيان.
enum Scheduler {
    static func schedule(_ card: Card, grade: ReviewGrade, now: Date = Date()) -> Card {
        var c = card
        let q = Double(grade.rawValue)
        if grade == .again {
            c.repetitions = 0
            c.interval = 0
            c.lapses += 1
        } else {
            switch c.repetitions {
            case 0: c.interval = 1
            case 1: c.interval = 6
            default: c.interval = max(1, Int((Double(c.interval) * c.easeFactor).rounded()))
            }
            if grade == .hard { c.interval = max(1, Int((Double(c.interval) * 0.75).rounded())) }
            if grade == .easy { c.interval = Int((Double(c.interval) * 1.3).rounded()) }
            c.repetitions += 1
        }
        c.easeFactor = max(1.3, c.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        c.reviewCount += 1
        c.lastReviewed = now
        let seconds: TimeInterval = grade == .again ? 10 * 60 : Double(c.interval) * 86_400
        c.dueDate = now.addingTimeInterval(seconds)
        return c
    }

    /// نص المدة التقريبية التي سيظهر بها زر التقييم.
    static func previewInterval(_ card: Card, grade: ReviewGrade) -> String {
        let c = schedule(card, grade: grade)
        if grade == .again { return "١٠ د" }
        return c.interval == 1 ? "يوم" : "\(c.interval) يوم"
    }
}

/// بطاقة مقترحة مستخرجة من نص ممسوح، قبل اعتمادها.
struct DraftCard: Identifiable, Hashable {
    enum Kind: String { case pair, question, cloze }
    var id: UUID = UUID()
    var front: String
    var back: String
    var kind: Kind
    var selected: Bool = true
}
