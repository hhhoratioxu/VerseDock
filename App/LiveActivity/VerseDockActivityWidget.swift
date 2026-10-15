import SwiftUI
import WidgetKit
import ActivityKit

@main struct VerseDockWidgetBundle: WidgetBundle {
    var body: some Widget { VerseDockActivityWidget() }
}

struct VerseDockActivityWidget: Widget {
    private let accent = Color(red: 0.72, green: 0.91, blue: 0.58)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("VerseDock · Spotify", systemImage: "waveform").font(.caption.weight(.semibold))
                    Spacer()
                    Text(context.isStale ? "等待更新" : (context.state.isPlaying ? "正在播放" : "已暂停"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(context.state.line).font(.title3.bold()).foregroundStyle(accent).lineLimit(2)
                Text(context.state.title + " · " + context.state.artist).font(.caption).lineLimit(1)
                if !context.state.nextLine.isEmpty { Text(context.state.nextLine).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }.padding(16).activityBackgroundTint(.black.opacity(0.85)).activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("VerseDock", systemImage: "waveform").font(.caption).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill").foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(context.state.line).font(.headline).foregroundStyle(accent).lineLimit(2)
                        Text(context.isStale ? "等待更新 · 返回 App 或检查 Mac 推送桥" : context.state.nextLine)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }.padding(.vertical, 6)
                }
            } compactLeading: {
                Image(systemName: "waveform").foregroundStyle(accent)
            } compactTrailing: {
                // The compact region has very little space; the complete line lives in the expanded region.
                Text(String(context.state.line.prefix(6))).font(.caption2).foregroundStyle(accent).lineLimit(1)
            } minimal: {
                Image(systemName: context.isStale ? "clock" : "waveform").foregroundStyle(accent)
            }.keylineTint(accent)
        }
    }
}
