# 当前验收记录

验收日期：2026 年 10 月 13 日，Asia/Shanghai。这个文件记录此次实际完成的检查，源码实现、类型检查、真实 Spotify 接入和 iOS 真机效果分别列出。

| 项目 | 结果与证据 |
|---|---|
| Mac arm64 编译 | 通过。`Evidence/mac-build.txt`；产物 `build/VerseDock.app`。最低 macOS 14，本机临时签名。 |
| Mac 主窗口 | 已实际打开，检查到歌曲卡片、歌词区域、进度、校准按钮、导入和设置入口。 |
| 原创演示同步 | 已运行原创测试歌词，实际观察到当前行高亮、进度推进和滚动跟随。演示界面明确标注未连接真实播放。 |
| Mac 桌面悬浮 | 已实际打开。关闭主窗口后，悬浮歌词窗口仍显示，观察到 Spotify 当前歌曲和播放状态。 |
| Mac 真实 Spotify 读取 | 通过。实际读到「有没有 / 張靚穎」和「說好不哭 / 周杰倫」等正在播放的歌曲、封面、时长和进度；能够随歌曲变化更新。仅作为本机接入记录，未导出账户资料。 |
| 在线歌词 | 已实际开启并发起 LRCLIB 查询。测试中的歌曲返回未匹配，App 显示「没有找到匹配歌词，可以导入 LRC」。没有把无匹配报告为同步歌词成功。 |
| LRC 与授权核心 | 13 个 XCTest 全部通过，0 失败。覆盖重复时间戳、双语、offset、无效输入、校准、暂停、跳转边界、PKCE 标准向量、state 与重复参数拒绝、表单编码、429 错误。见 `Evidence/core-tests.txt`。 |
| 推送桥 | 7 项测试全部通过，0 失败。包含真实本地 HTTP 鉴权、内容状态结构、输入边界、限流、无注册活动、APNs 失败和过期令牌清理。APNs 使用测试替身，没有连接真实 Apple 推送。见 `Evidence/relay-tests.txt`。 |
| iOS 主 App 源码 | 使用已安装的 iPhoneOS SDK 和 Swift 编译器进行类型检查，通过。见 `Evidence/ios-typecheck.txt`。 |
| 实时活动扩展源码 | 同样通过类型检查，包含 compact / minimal / expanded 灵动岛与锁屏布局。类型检查不包含 WidgetKit 真机布局验收。 |
| Xcode 工程结构 | `project.pbxproj` 与 Info.plist 通过 `plutil -lint`。工程包含共享静态核心、Mac App、iOS App 与嵌入的实时活动扩展。 |
| Xcode 标准构建 | 未完成：本机 Xcode 返回未接受 Apple 许可。没有替用户接受条款。 |
| iOS 模拟器 | 未运行：本机 simctl 所需的 CoreSimulator 可执行文件缺失。没有安装运行时或更改开发环境。 |
| iPhone/iPad 真机 | 未运行：当前交付范围由用户选择为 Mac App 和两端源码；没有 Apple Team 签名、设备安装、Spotify Client ID、HTTPS 回调和 APNs 私钥配置。 |
| 灵动岛后台推送送达 | 未验收。服务代码和客户端注册/发送路径已实现，仍需签名后的真机及 Apple APNs 配置。Mac 必须保持运行；Apple 可能延迟或合并推送。 |
| Intel Mac、正式分发、公证 | 未验收。当前可执行产物只验证了本机 Apple Silicon。 |

## 检查证据的命令

```sh
zsh scripts/test-core.sh
zsh scripts/check-ios.sh
zsh scripts/build-mac.sh
plutil -lint VerseDock.xcodeproj/project.pbxproj Config/Mac-Info.plist Config/iOS-Info.plist Config/Widget-Info.plist
cd relay
.venv/bin/python -m unittest -v test_server.py
```

核心测试使用真正的 XCTest，不以编译通过代替执行结果。推送服务使用 APNs 替身的测试只证明本地协议和错误处理，不证明真实推送到达。在线歌词无匹配是准确呈现的服务结果，歌词覆盖率仍取决于歌词提供方。
