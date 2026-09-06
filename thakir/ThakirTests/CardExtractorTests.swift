import XCTest
@testable import Thakir

final class CardExtractorTests: XCTestCase {
    func testColonPairBecomesTermDefinition() {
        let drafts = CardExtractor.extract(from: "التمثيل الضوئي: عملية تصنع فيها النباتات غذاءها بضوء الشمس")
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].kind, .pair)
        XCTAssertEqual(drafts[0].front, "التمثيل الضوئي")
        XCTAssertTrue(drafts[0].back.hasPrefix("عملية"))
    }

    func testQuestionFollowedByAnswer() {
        let text = "ما هي عاصمة السعودية؟\nالرياض هي العاصمة"
        let drafts = CardExtractor.extract(from: text)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].kind, .question)
        XCTAssertEqual(drafts[0].back, "الرياض هي العاصمة")
    }

    func testPlainSentenceBecomesCloze() {
        let drafts = CardExtractor.extract(from: "يتكوّن الغلاف الجوي من النيتروجين والأكسجين وغازات أخرى")
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].kind, .cloze)
        XCTAssertTrue(drafts[0].front.contains("______"))
        XCTAssertFalse(drafts[0].front.contains(drafts[0].back))
    }

    func testTimeLikeColonIsNotAPair() {
        XCTAssertNil(CardExtractor.splitPair("الاجتماع الساعة 10:30 صباحًا"))
    }

    func testShortLinesIgnored() {
        XCTAssertTrue(CardExtractor.extract(from: "أ\nب\n").isEmpty)
    }
}
