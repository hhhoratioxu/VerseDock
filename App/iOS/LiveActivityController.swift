import ActivityKit
import SwiftUI
import VerseCore

@MainActor final class LiveActivityController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "实时活动未启动"
    private var activity: Activity<LyricsActivityAttributes>?
    private var tokenTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var activityStateTask: Task<Void, Never>?
    private var lastUpdate = Date.distantPast
    private var lastSignature = ""
    private var generation = 0
    private var relayBase = ""
    private var relayCredential = ""
    private var registeredID: String?

    func start(state: RelayState, relayURL: String, relayKey: String) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw VerseError.message("请在系统设置中允许 VerseDock 实时活动") }
        guard activity == nil else { return }
        generation += 1
        let requestGeneration = generation
        // Recover old activities after a process relaunch, then create one explicit session.
        for previous in Activity<LyricsActivityAttributes>.activities { Task { await previous.end(nil, dismissalPolicy: .immediate) } }
        let attributes = LyricsActivityAttributes(sessionName: "VerseDock")
        let value = try Activity.request(attributes: attributes, content: content(state), pushType: relayURL.isEmpty ? nil : .token)
        activity = value; isRunning = true; lastSignature = ""
        activityStateTask = Task {
            for await state in value.activityStateUpdates {
                guard generation == requestGeneration, !Task.isCancelled else { return }
                if state == .dismissed || state == .ended {
                    stop(); return
                }
            }
        }
        status = relayURL.isEmpty ? "前台更新已启用 · 后台显示最近一条" : "正在注册后台推送"
        relayBase = relayURL; relayCredential = relayKey
        if !relayURL.isEmpty {
            tokenTask = Task {
                for await token in value.pushTokenUpdates {
                    guard !Task.isCancelled, generation == requestGeneration else { return }
                    let hex = token.map { String(format: "%02x", $0) }.joined()
                    struct Registration: Encodable { let activityID: String; let token: String }
                    do {
                        try await RelayClient.send(Registration(activityID: value.id, token: hex), path: "register",
                            base: relayURL, key: relayKey)
                        guard generation == requestGeneration else {
                            try? await unregister(value.id, base: relayURL, key: relayKey); return
                        }
                        registeredID = value.id; status = "后台推送已注册 · 需 Mac 在线"
                    } catch { status = "推送注册失败：\(error.localizedDescription)" }
                }
            }
        }
    }
    func update(state: RelayState) {
        guard let activity, updateTask == nil else { return }
        let signature = "\(state.title)|\(state.line)|\(state.nextLine)|\(state.isPlaying)|\(state.source)"
        guard signature != lastSignature || Date().timeIntervalSince(lastUpdate) >= 20 else { return }
        lastSignature = signature
        lastUpdate = Date()
        updateTask = Task {
            await activity.update(content(state))
            updateTask = nil
        }
    }
    func markBackground() {
        if isRunning, relayBase.isEmpty { status = "后台只显示最近歌词 · 返回 App 恢复同步" }
    }
    func stop() {
        generation += 1; tokenTask?.cancel(); tokenTask = nil
        activityStateTask?.cancel(); activityStateTask = nil
        updateTask?.cancel(); updateTask = nil
        let old = activity, id = registeredID, base = relayBase, key = relayCredential
        let restored = Activity<LyricsActivityAttributes>.activities
        activity = nil; isRunning = false; registeredID = nil; status = "实时活动已结束"
        Task {
            if let old { await old.end(nil, dismissalPolicy: .immediate) }
            // Also remove activities restored by the OS after relaunch.
            for value in restored { await value.end(nil, dismissalPolicy: .immediate) }
            if let id { try? await unregister(id, base: base, key: key) }
        }
    }
    private func unregister(_ id: String, base: String, key: String) async throws {
        struct Removal: Encodable { let activityID: String }
        try await RelayClient.send(Removal(activityID: id), path: "unregister", base: base, key: key)
    }
    private func content(_ value: RelayState) -> ActivityContent<LyricsActivityAttributes.ContentState> {
        ActivityContent(state: .init(title: value.title, artist: value.artist, line: value.line,
            nextLine: value.nextLine, isPlaying: value.isPlaying, source: value.source,
            updatedAt: value.updatedAt, position: value.position, duration: value.duration),
            staleDate: Date().addingTimeInterval(30))
    }
}

struct ActivityButton: View {
    @ObservedObject var model: VerseModel
    @ObservedObject var controller: LiveActivityController
    var body: some View {
        Button { model.toggleActivity() } label: {
            Label(controller.isRunning ? "结束实时活动" : "开启灵动岛", systemImage: "capsule")
        }
    }
}
