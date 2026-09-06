import Foundation

/// يحوّل نصًا خامًا (من الكاميرا أو اللصق) إلى بطاقات مقترحة.
enum CardExtractor {
    static let separators = [" : ", ":", "：", " - ", " – ", " — ", " = ", "="]

    static func extract(from text: String) -> [DraftCard] {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }

        var drafts: [DraftCard] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if let pair = splitPair(line) {
                drafts.append(DraftCard(front: pair.0, back: pair.1, kind: .pair))
                i += 1
                continue
            }
            if isQuestion(line), i + 1 < lines.count, !isQuestion(lines[i + 1]) {
                drafts.append(DraftCard(front: line, back: lines[i + 1], kind: .question))
                i += 2
                continue
            }
            if let cloze = makeCloze(line) {
                drafts.append(cloze)
            }
            i += 1
        }
        return drafts
    }

    /// يقسم السطر عند أول فاصل تعريف مثل «المصطلح: التعريف».
    static func splitPair(_ line: String) -> (String, String)? {
        for sep in separators {
            guard let range = line.range(of: sep) else { continue }
            let front = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let back = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            // نتجاهل الفواصل داخل الأرقام والأوقات مثل 10:30
            if front.count >= 2, back.count >= 2, !(front.last?.isNumber == true && back.first?.isNumber == true) {
                return (front, back)
            }
        }
        return nil
    }

    static func isQuestion(_ line: String) -> Bool {
        line.hasSuffix("؟") || line.hasSuffix("?")
            || ["ما ", "ماذا ", "لماذا ", "كيف ", "متى ", "أين ", "من ", "عرّف ", "عرف ", "اذكر ", "علل "]
                .contains { line.hasPrefix($0) }
    }

    /// يخفي أطول كلمة ذات معنى في الجملة لتكوين بطاقة «أكمل الفراغ».
    static func makeCloze(_ line: String) -> DraftCard? {
        let words = line.split(separator: " ").map(String.init)
        guard words.count >= 4 else { return nil }
        let stop: Set<String> = ["على", "إلى", "من", "في", "عن", "التي", "الذي", "هذا", "هذه", "ذلك", "كان", "كانت", "هو", "هي", "the", "and", "with", "from", "that", "this"]
        let candidates = words.filter { w in
            let clean = w.trimmingCharacters(in: .punctuationCharacters)
            return clean.count >= 4 && !stop.contains(clean) && !clean.allSatisfy(\.isNumber)
        }
        guard let target = candidates.max(by: { $0.count < $1.count }) else { return nil }
        let clean = target.trimmingCharacters(in: .punctuationCharacters)
        let front = line.replacingOccurrences(of: clean, with: "______")
        return DraftCard(front: front, back: clean, kind: .cloze)
    }
}
