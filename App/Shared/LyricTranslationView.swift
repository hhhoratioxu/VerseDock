import SwiftUI
import Translation
import NaturalLanguage
import VerseCore

struct TranslationLanguage: Identifiable, Equatable {
    let id: String
    let name: String
}

struct LyricTranslationHost: ViewModifier {
    @ObservedObject var model: VerseModel
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.background { SystemLyricTranslation(model: model).frame(width: 1, height: 1).accessibilityHidden(true) }
        } else { content }
    }
}

@available(macOS 15.0, iOS 18.0, *)
private struct SystemLyricTranslation: View {
    @ObservedObject var model: VerseModel
    @State private var configuration: TranslationSession.Configuration?
    @State private var job: Job?
    private struct Job {
        let revision: UUID
        let plan: LyricTranslationPlan
        let source: Locale.Language
        let target: Locale.Language
    }
    var body: some View {
        Color.clear
            .task {
                let languages = await LanguageAvailability().supportedLanguages
                let locale = Locale(identifier: "zh_CN")
                model.translationLanguages = languages.map { language in
                    let id = language.minimalIdentifier
                    return TranslationLanguage(id: id, name: locale.localizedString(forIdentifier: id) ?? id)
                }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            .task(id: model.translationRevision) { await prepare() }
            .translationTask(configuration) { session in
                guard let job, model.translationRevision == job.revision, model.translationEnabled,
                      session.sourceLanguage?.minimalIdentifier == job.source.minimalIdentifier,
                      session.targetLanguage?.minimalIdentifier == job.target.minimalIdentifier else { return }
                do {
                    model.translationStatus = "正在翻译 · 首次使用请按系统提示下载语言包"
                    try await session.prepareTranslation()
                    try Task.checkCancellation()
                    let requests = job.plan.units.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
                    var completed = 0
                    for try await response in session.translate(batch: requests) {
                        try Task.checkCancellation()
                        guard model.translationEnabled, model.translationRevision == job.revision else { return }
                        guard let id = response.clientIdentifier,
                              let original = job.plan.original(id: id, matching: response.sourceText) else { continue }
                        let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !translated.isEmpty { model.translatedLines[original] = translated }
                        completed += 1
                        model.translationStatus = "正在翻译 \(completed)/\(requests.count) · Apple 系统翻译"
                    }
                    guard model.translationRevision == job.revision else { return }
                    model.translationStatus = completed == requests.count
                        ? "Apple 系统翻译 · 机器译文仅供参考"
                        : "部分歌词未翻译，可重试"
                } catch {
                    guard !Task.isCancelled, model.translationRevision == job.revision else { return }
                    model.translationStatus = "翻译未完成：\(error.localizedDescription) · 可在设置中重试"
                }
            }
    }
    @MainActor private func prepare() async {
        job = nil
        guard model.translationEnabled, let document = model.lyrics else { configuration = nil; return }
        let revision = model.translationRevision
        let plan = LyricTranslationPlan(document: document)
        guard !plan.units.isEmpty else { configuration = nil; model.translationStatus = "暂无可翻译的歌词"; return }
        // Credits at the start of a synchronized lyric often use a different language from the song.
        let skip = min(8, plan.units.count / 4)
        let sample = String(plan.units.dropFirst(skip).prefix(24).map(\.text).joined(separator: "\n").prefix(4000))
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let detected = model.translationSource == "auto" ? recognizer.dominantLanguage?.rawValue : model.translationSource else {
            configuration = nil; model.translationStatus = "无法识别原词语言，请在设置中指定"; return
        }
        let source = Locale.Language(identifier: model.translationSource == "auto" ? detected : model.translationSource)
        let target = Locale.Language(identifier: model.translationTarget)
        if source.languageCode == target.languageCode && source.script == target.script {
            configuration = nil; model.translationStatus = "原词已是目标语言，无需翻译"; return
        }
        let status = await LanguageAvailability().status(from: source, to: target)
        guard !Task.isCancelled, revision == model.translationRevision else { return }
        guard status != .unsupported else {
            configuration = nil; model.translationStatus = "系统暂不支持这个语言组合，请更换目标或指定原词语言"; return
        }
        job = Job(revision: revision, plan: plan, source: source, target: target)
        var next = configuration ?? .init(source: source, target: target)
        next.source = source; next.target = target
        next.invalidate() // Same-language retries and successive songs must create a fresh session as well.
        configuration = next
    }
}
