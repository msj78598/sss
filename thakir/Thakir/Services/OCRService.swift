import Foundation
import UIKit
import Vision

/// استخراج النص من الصور على الجهاز عبر Vision، مع دعم العربية حين يتوفر.
enum OCRService {
    static var supportsArabic: Bool {
        let langs = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequest.currentRevision)) ?? []
        return langs.contains { $0.hasPrefix("ar") }
    }

    static func recognize(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = cgOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            var languages = ["en-US"]
            if supportsArabic { languages.insert("ar", at: 0) }
            request.recognitionLanguages = languages
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            // ترتيب الأسطر من الأعلى إلى الأسفل (إحداثيات Vision تبدأ من الأسفل)
            let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            return sorted.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
