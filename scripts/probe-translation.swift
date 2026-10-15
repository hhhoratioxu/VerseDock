import Foundation
import Translation

@main struct TranslationProbe {
    static func main() async {
        guard #available(macOS 15.0, *) else { print("System translation requires macOS 15+"); return }
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        let source = Locale.Language(identifier: "en")
        let targetID = CommandLine.arguments.dropFirst().first ?? "zh-Hans"
        let target = Locale.Language(identifier: targetID)
        let status = await availability.status(from: source, to: target)
        var report: [String: Any] = ["supportedLanguages": languages.map(\.minimalIdentifier).sorted(),
            "testedSource": "en", "testedTarget": targetID, "languagePairStatus": String(describing: status),
            "translationPerformed": false]
        // Only use already installed models: this diagnostic never approves downloads on the user's behalf.
        if #available(macOS 26.0, *), status == .installed {
            do {
                let session = TranslationSession(installedSource: source, target: target)
                let response = try await session.translate("The melody gathers the night. We will meet again in the next song.")
                report["translationPerformed"] = !response.targetText.isEmpty
                report["originalAuthoredSample"] = response.sourceText
                report["translatedAuthoredSample"] = response.targetText
            } catch { report["error"] = error.localizedDescription }
        }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text) }
    }
}
