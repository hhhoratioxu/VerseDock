# VerseDock 安装与配置

## Mac

1. 下载并解压 Mac ZIP，将 `VerseDock.app` 放进“应用程序”后双击；自行构建则运行 `build/VerseDock.app`。运行时显示 Dock 图标，点击 Dock 可重新打开主窗口。
2. 打开 Spotify 桌面 App，开始播放。VerseDock 会每秒读取本地歌曲和播放状态，每 0.1 秒更新自己的同步时间轴。
3. 允许系统自动化权限。若拒绝过，进入「系统设置 → 隐私与安全性 → 自动化」，允许 VerseDock 读取 Spotify。
4. 默认自动查找 LRCLIB、QQ 音乐、网易云和 lyrics.ovh，失败会换源；旧版本已关闭联网的设置会保留，可在设置里重新开启。也可导入 UTF-8 `.lrc` / `.txt` 文件。导入文件绑定当前 Spotify 歌曲 ID。重试按钮跳过缓存，实际来源和时长差异会显示在窗口下方。
5. 点击「悬浮歌词」。拖动歌词或窗口空白处即可移动，位置和尺寸自动保存；右键可隐藏或调整字号。顶部状态栏默认 18 个字符、静态显示；可在状态栏菜单或设置里加宽并独立选择是否滚动，偏好自动保存。关闭主窗口后仍继续显示，Dock 和菜单栏均可重新打开主窗口。校准的正值使歌词提前，负值使歌词延后；每首歌单独保存。点击有时间戳的歌词行会跳到实际演唱时间。

6. 设置中「优先使用 Spotify 原词」默认开启。点击「连接 / 查看 Spotify 原词会话」，在独立窗口自行登录官方网页；需要时使用「前往 Spotify 登录」。该接入使用非公开网页接口，可能失效，本机已实测有词时优先、无词后备用。取得原词就优先显示，无词或暂时读取失败后进入备用，并区分这两种原因。可指定备用歌词来源，默认「自动」；手动模式只访问所选备用。YouTube Music 与 Apple Music 歌词目前未接通，实际来源始终标明。
7. 翻译默认关闭。在「歌词翻译」开启并选择目标语言，首次按系统提示下载语言包；需要 macOS 15 / iOS 18 及以上。原词上方、译文下方，关闭后译文消失。自动识别不准确时可指定原词语言，不支持的语言组合会提示。

原创演示只用于检查 UI 和同步时间轴，界面明确标注，绝不作为真实 Spotify 接入的替代证据。

当前 App 使用本机临时签名，适合开发验收。向其他电脑分发需要 Apple 开发者签名与公证；本次没有完成这两个发布步骤。直接构建脚本的目标是 Apple Silicon。本工程可在 Xcode 配置其他架构，但 Intel 尚未测试。

## 界面与 Liquid Glass

0.1.8 使用系统工具栏；Mac 的齿轮与 ⌘, 打开独立设置窗口，iPhone/iPad 使用可返回的系统分类列表。设置分为「外观、歌词、翻译、连接」四页。外观页保留玻璃、封面背景和 Mac 显示选项，歌词页管理来源与原词会话，翻译页选择语言，连接页管理手机授权与推送桥。顶部「更多操作」可重新查找、导入 LRC 或试用原创演示。大窗口会展开封面与歌词双栏，小窗口自动回到紧凑布局；Mac 新窗口默认 900 × 660。

设置提供「Liquid Glass 强度」滑块（最通透 → 色调最浓）与独立的「背景色彩浓度」滑块，均即时预览并自动保存。专辑背景从真实封面在本机提取配色，切歌柔和换色；可单独关闭「专辑封面背景」或「背景柔和流动」。新默认值为玻璃 40%、背景 65%。没有可用封面时回到中性色；控件文字不随强度变透明。主窗口工具栏由系统决定原生外观；App 内的强度滑块调整底部小型工具组、悬浮窗与设置中的预览，不会覆盖系统工具栏的玻璃偏好。中间强度的色调更轻，100% 仍保留完整色调。设置窗口跟随系统外观，听歌窗口保留深色背景。

设置中的「外观与交互」可以关闭界面动效，默认开启。macOS / iOS / iPadOS 26 及以上使用系统原生 Liquid Glass；旧系统保留磨砂材质。减少动态效果和减少透明度遵循系统偏好，应用不会替用户修改这些系统设置。来源详情、翻译状态与时间校准从主窗口底部打开，现有歌词来源、翻译语言、状态栏宽度和滚动偏好保留。

构建此版本需要包含 macOS 26、iPhoneOS 26 或更新 SDK 的 Xcode；运行时仍保留 macOS 14 / iOS 17 的兼容路径。本机使用 Xcode 27 构建。

## 接受 Xcode 许可与完善开发环境

2026-10-13 首次交付时，本机 `xcodebuild` 返回未接受许可。2026-10-15 重新检查时，许可与首次启动检查已经通过，已能完整构建设备版本。如果在你的其他电脑遇到许可提示，请自行阅读并接受 Xcode 条款。本项目的构建脚本不会替你接受条款、修改系统开发者目录或安装运行时。

完成后打开 `VerseDock.xcodeproj`：

- Mac scheme：`VerseDockMac`。
- iPhone/iPad scheme：`VerseDock`，同时构建 `VerseCore` 与 `VerseDockActivity` 扩展。
- 在 App 和扩展的 Signing & Capabilities 中选择同一 Apple Team。
- 可修改包名，但扩展包名必须以主 App 包名为前缀，服务端 APNS_BUNDLE_ID 必须与主 App 包名完全一致。
- 当前主 App 包名：`com.horatio.versedock`；扩展：`com.horatio.versedock.activity`。
- 开发签名使用 `APNS_ENVIRONMENT=development`，服务端 `APNS_ENV=sandbox`。TestFlight / 正式分发必须调整到生产环境和匹配的 provisioning profile。
- APNs 推送能力通常需要有相应权限的 Apple Developer 团队、证书与配置文件。无有效签名不会产生可直接安装的真机 IPA。

## Spotify 官方授权

Mac 本地接入无需这些步骤；iOS 读取账户播放状态需要它们。

1. 在你的 Spotify Developer Dashboard 配置一个 App，复制 Client ID。开发模式要求 App 所有者有 Spotify Premium，并将实际登录账户加入允许的用户列表。当前新 App 用户上限为 5。
2. 将 `web/callback.html`、`callback.js`、`callback.css` 放在你控制的 HTTPS 站点中，保持相对文件路径。示例最终地址：`https://你自己的域名/callback.html`。
3. 将最终 HTTPS 地址原样登记为 Spotify Redirect URI。Spotify 要求精确匹配，普通 HTTP 域名和 `localhost` 不符合当前要求。
4. 在 VerseDock iOS 设置填写 Client ID 与相同回调地址，然后点「连接 Spotify」。
5. 浏览器授权后，回调页显示「返回 VerseDock」。点击后通过 `versedock://oauth` 交还授权码；App 验证随机 state，再使用 PKCE verifier 换取令牌。Spotify 登记的是 HTTPS 回调，不是自定义 scheme。
6. 回调站点不应加入统计脚本，代理访问日志应关闭或屏蔽 query string，避免记录短期授权码。页面本身关闭 referrer、立即去除地址栏参数，且不向服务端兑换或保存 Spotify 令牌。

工程申请 `user-read-currently-playing` 和 `user-modify-playback-state`，后者用于点击歌词跳转；旧版本已连接的账户需要重新授权才能获得新权限。Spotify 的跳转接口要求 Premium。不会申请修改歌单或读取密码权限。网络轮询在前台每 3 秒一次，429 尊重 Retry-After，401 尝试一次刷新，403 明确显示账户/开发者权限错误。授权使用系统浏览器会话；令牌存在本机 Keychain。这个官方播放授权与上面可选的网页歌词登录相互独立，不能用播放授权代替歌词会话。

## 灵动岛与 iPad 锁屏

在有灵动岛的 iPhone 上点击「开启灵动岛」。紧凑区域最多显示约 6 个字符；长按展开显示当前句、下一句和歌名。其他 iPhone 与 iPad 使用锁屏实时活动。iPad 没有灵动岛；设备和系统是否允许实时活动，以实际返回与系统设置为准。

实时活动前台更新与完整歌词窗口共用同一状态。开启翻译后，展开区域和锁屏显示原词上、译文下；紧凑灵动岛仍仅显示短原词。后台需要推送。未设置推送桥时，歌词会保留最近一条，30 秒后进入等待更新状态；这是系统限制，不能当作后台逐句同步。

## 部署可选 APNs 推送桥

桥接服务已编写，但没有部署到你的服务器，也没有修改现有 ECS、DNS 或网络配置。你需要选择一个可用的 HTTPS 地址，并在服务器上准备 Apple APNs `.p8` 密钥、Key ID、Team ID。请勿将私钥粘贴到聊天、App 设置或源码仓库。

准备 Python 3.9+，在 `relay/` 目录建立独立环境：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

配置进程环境（真实值请放入受保护的服务配置文件，不要提交到仓库）：

| 变量 | 用途 |
|---|---|
| RELAY_KEY | 随机配对密钥，至少 32 字符；Mac 和 iOS 两端填写相同值 |
| APNS_TEAM_ID | Apple Developer Team ID |
| APNS_KEY_ID | APNs signing Key ID |
| APNS_KEY_PATH | 服务器上的 `.p8` 私钥绝对路径，限制读取权限 |
| APNS_BUNDLE_ID | iOS 主 App 包名，当前为 `com.horatio.versedock` |
| APNS_ENV | `sandbox` 或 `production`，与 App 签名环境匹配 |
| RELAY_PORT | 本机监听端口，默认 8787 |
| RELAY_DB | 活动注册数据库路径，默认 `activities.sqlite` |

随后运行 `.venv/bin/python server.py`。服务仅监听 `127.0.0.1`，需你自己的 HTTPS 反向代理。原样转发 `/register`、`/unregister`、`/update`，不要移除 Authorization；服务也提供 `/callback.html`、`/callback.js`、`/callback.css`，可同时用作上面的 Spotify 回调站点。两端填服务的根 HTTPS 地址。

双语后台推送要求 Mac 与 iOS 两端开启翻译并选择同一目标语言。iOS 改变翻译偏好会结束旧活动，需重新开启；未开启或目标不匹配的手机不会收到译文。升级此版本也需同步更新推送桥。

配对顺序：

1. Mac 和 iOS 两端填写服务地址与相同 RELAY_KEY，开启「后台推送桥」并保存。
2. 在 iOS App 中结束旧实时活动，再开启新活动，使系统申请 push token。
3. 确认 iOS 显示「后台推送已注册」，Mac 设置显示歌词发送成功。
4. Mac Spotify 保持播放，Mac VerseDock 持续运行，再切换 iPhone App 到后台或锁屏检查。
5. 活动结束时取消注册；APNs 报告过期令牌时服务端清除。单个服务只服务一个配对家庭/用户组，最多 8 个活动；不要多租户共享同一个密钥。

Mac 是这个桥接模式的播放与歌词来源。如果要支持「Mac 关机、iPhone 独立播放也能后台更新」，需要另一项服务端 Spotify OAuth 与轮询功能；本版本没有实现，也没有声称支持。

APNs `200` 只表示 Apple 接受推送，不表示设备已经显示。工程使用低优先级推送和 30 秒过期时间避免积压旧歌词；每次发送至少间隔 5 秒。Apple 仍可能延迟、合并或限制更新，因此不能承诺卡拉 OK 级别的后台精确逐句同步。真机必须检查实际到达和显示。

## 来源参考

- [Spotify 当前播放接口](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track)
- [Spotify PKCE 授权流程](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- [Spotify 回调地址规则](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri)
- [Spotify 2026 开发模式限制](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)
- [Apple ActivityKit APNs 更新机制](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [Apple 后台执行模式](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
- [LRCLIB API 文档](https://lrclib.net/docs)

这些链接用于确认接口与平台规则，不是复制插件实现。
