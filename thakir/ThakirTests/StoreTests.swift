import XCTest
@testable import Thakir

final class StoreTests: XCTestCase {
    private func makeStore() -> Store {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thakir-test-\(UUID().uuidString).json")
        return Store(fileURL: url)
    }

    func testAddDeckAndCardsPersistsAcrossReload() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("thakir-persist-\(UUID().uuidString).json")
        let store = Store(fileURL: url)
        let deck = store.addDeck(name: "أحياء", emoji: "🧬")
        store.addCards([Card(front: "س", back: "ج")], to: deck.id)

        let reloaded = Store(fileURL: url)
        XCTAssertEqual(reloaded.decks.count, 1)
        XCTAssertEqual(reloaded.decks[0].cards.count, 1)
        XCTAssertEqual(reloaded.decks[0].name, "أحياء")
    }

    func testReviewUpdatesCardAndLog() {
        let store = makeStore()
        let deck = store.addDeck(name: "كيمياء", emoji: "⚗️")
        let card = Card(front: "س", back: "ج")
        store.addCards([card], to: deck.id)
        store.review(card, in: deck.id, grade: .good)
        XCTAssertEqual(store.decks[0].cards[0].reviewCount, 1)
        XCTAssertEqual(store.reviewLog.count, 1)
        XCTAssertEqual(store.streak, 1)
        XCTAssertEqual(store.totalDue, 0)
    }

    func testDueCardsSortedByDueDate() {
        let store = makeStore()
        let deck = store.addDeck(name: "فيزياء", emoji: "⚛️")
        var early = Card(front: "1", back: "1"); early.dueDate = Date(timeIntervalSinceNow: -7200)
        var late = Card(front: "2", back: "2"); late.dueDate = Date(timeIntervalSinceNow: -60)
        var future = Card(front: "3", back: "3"); future.dueDate = Date(timeIntervalSinceNow: 3600)
        store.addCards([late, future, early], to: deck.id)
        let due = store.dueCards()
        XCTAssertEqual(due.map { $0.card.front }, ["1", "2"])
    }
}
