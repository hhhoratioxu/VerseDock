import AppKit
import VerseCore

actor SpotifyReader {
    func seek(to position: Double, track: Track) throws -> PlaybackSnapshot? {
        _ = try PlaybackSeeking.milliseconds(position, duration: track.duration)
        let source = """
        on verseSeek(expectedID, targetPosition)
            with timeout of 3 seconds
                tell application id "com.spotify.client"
                    if player state is stopped then return false
                    if id of current track is not expectedID then return false
                    set player position to targetPosition
                    return true
                end tell
            end timeout
        end verseSeek
        """
        let arguments = NSAppleEventDescriptor.list()
        arguments.insert(NSAppleEventDescriptor(string: track.id), at: 1)
        arguments.insert(NSAppleEventDescriptor(double: position), at: 2)
        // Call a fixed handler with data descriptors; no song data enters executable AppleScript.
        let event = NSAppleEventDescriptor(eventClass: 0x61736372, eventID: 0x70736272,
            targetDescriptor: nil, returnID: -1, transactionID: 0)
        event.setParam(NSAppleEventDescriptor(string: "verseseek"), forKeyword: 0x736e616d)
        event.setParam(arguments, forKeyword: 0x2d2d2d2d)
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAppleEvent(event, error: &error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            throw VerseError.message(code == -1743 ? "请在系统自动化设置中允许 VerseDock 控制 Spotify" : "Spotify 跳转失败（\(code)）")
        }
        guard result?.booleanValue == true else { throw VerseError.message("歌曲已经变化或停止，请点击当前歌曲的歌词") }
        return try snapshot()
    }
    func snapshot() throws -> PlaybackSnapshot? {
        // Fixed script; track titles, imported lyrics and network input never enter executable code.
        let source = """
        with timeout of 3 seconds
            tell application id "com.spotify.client"
                if player state is stopped then return {}
                set t to current track
                return {id of t, name of t, artist of t, album of t, duration of t, player position, (player state is playing), artwork url of t}
            end tell
        end timeout
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw VerseError.message("请在系统设置 → 隐私与安全性 → 自动化，允许 VerseDock 读取 Spotify") }
            throw VerseError.message("Spotify 读取失败（\(code)），请确认正在播放歌曲")
        }
        guard let result, result.numberOfItems == 8,
              let id = result.atIndex(1)?.stringValue, !id.isEmpty else { return nil }
        func string(_ index: Int) -> String { result.atIndex(index)?.stringValue ?? "" }
        // Spotify's current desktop implementation returns milliseconds despite the dictionary's seconds label.
        let duration = Double(result.atIndex(5)?.int32Value ?? 0) / 1000
        let position = Double(string(6)) ?? 0
        let track = Track(id: id, title: string(2), artist: string(3), album: string(4), duration: duration,
            artworkURL: URL(string: string(8)))
        return PlaybackSnapshot(track: track, position: position, isPlaying: result.atIndex(7)?.booleanValue ?? false)
    }
}
