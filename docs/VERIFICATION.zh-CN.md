# 当前验收记录

最新检查日期：2026 年 10 月 15 日，Asia/Shanghai。先列出图标更新和待签名 IPA 的新证据，随后保留 10 月 13 日首次交付记录。

## 2026-10-15：0.1.1 图标更新

| 项目 | 结果与证据 |
|---|---|
| 图标来源 | 使用内置 imagegen 生成 VerseDock 的 V 与歌词线图形，生成提示词与导出说明见 `Artwork/README.md`。没有下载或复用 Spotify 标志。 |
| 主图与 iOS 资源 | 1024 × 1024、不透明 PNG；Xcode 设备构建已编译 AppIcon 和 BrandMark，iPhone 与 iPad 的 Info.plist 均引用 AppIcon。 |
| Mac 资源与界面 | `.icns` 与 BrandMark 已进入应用 Resources；重新构建并打开 Mac App，实际看见窗口顶部的新 V 图形。 |
| Mac 下载包 | 从 ZIP 解压到临时目录后，严格代码签名校验通过，图标文件与源码资源一致。打包排除了本机 Finder 扩展属性。 |
| iOS 下载包 | 完整设备构建通过，IPA 包含 Assets.car、iPhone/iPad 图标及实时活动扩展；主 App 与扩展均为 0.1.1（2）。 |
| 验收边界 | iOS 仍为待签名 IPA，未新增真机安装或灵动岛运行证据；本次没有改动歌词、OAuth 或推送逻辑。资源检查摘要见 `Evidence/icon-assets.json`。 |

## 2026-10-15：完整 iOS 设备构建与待签名 IPA

| 项目 | 结果与证据 |
|---|---|
| 开发环境复核 | Xcode 27.0、Build 27A266a；许可与首次启动检查通过。没有执行替用户接受条款的命令。 |
| Apple 签名身份 | 本机查询得到 0 个有效代码签名身份；本次没有申请、导入或公开个人签名材料。 |
| iOS 主 App | 标准 `xcodebuild` Release 设备构建通过，产生实际 arm64 iPhoneOS 可执行文件；最低系统 17.0。 |
| 灵动岛/锁屏扩展 | 同一次构建完成 `VerseDockActivity.appex`，实际嵌入主 App 的 `PlugIns` 目录；平台、设备家族、Bundle ID 前缀和版本关系已核对。 |
| 待签名 IPA | `Payload/VerseDock.app` 标准布局，包含主程序和扩展；ZIP 完整性、Mach-O 平台、可执行权限及二进制哈希均核对。没有 Apple 签名和 embedded.mobileprovision。 |
| 公开构建摘要 | 见 `Evidence/ios-device-build.json`。完整原始构建日志留在本地 `build/ios-build.log`，不公开个人目录路径。 |
| 真机安装与运行 | 未验收。用户选择下载待签名 IPA，之后自己签名安装；不把成功编译、打包等同于真机可运行。 |
| Spotify OAuth / APNs | 尚无真实账户授权、签名设备或 APNs 送达证据；相关配置要求仍见安装说明。 |

## 2026-10-13：首次交付记录

以下是首次交付时的检查结果与当时的环境限制，不表示 10 月 15 日仍存在相同的构建阻断。

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
