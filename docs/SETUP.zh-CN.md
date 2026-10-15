# VerseDock 安装与配置

## Mac

1. 双击 `build/VerseDock.app`。
2. 打开 Spotify 桌面 App，开始播放。VerseDock 会每秒读取本地歌曲和播放状态，每 0.1 秒更新自己的同步时间轴。
3. 允许系统自动化权限。若拒绝过，进入「系统设置 → 隐私与安全性 → 自动化」，允许 VerseDock 读取 Spotify。
4. 在设置中开启 LRCLIB 在线歌词，或点右上角导入 UTF-8 `.lrc` / `.txt` 文件。导入文件绑定当前 Spotify 歌曲 ID。
5. 点击「悬浮歌词」。窗口支持拖动、调整尺寸、右键隐藏或调整字号。菜单栏入口可重新打开歌词主窗口。校准的正值使歌词提前，负值使歌词延后；每首歌单独保存。

原创演示只用于检查 UI 和同步时间轴，界面明确标注，绝不作为真实 Spotify 接入的替代证据。

当前 App 使用本机临时签名，适合开发验收。向其他电脑分发需要 Apple 开发者签名与公证；本次没有完成这两个发布步骤。直接构建脚本的目标是 Apple Silicon。本工程可在 Xcode 配置其他架构，但 Intel 尚未测试。

## 接受 Xcode 许可与完善开发环境

本机 `xcodebuild` 明确返回未接受许可。请由你打开 Xcode，阅读并接受 Apple 条款，完成 Xcode 的首次启动和需要的系统组件安装。也可以在终端执行 `sudo xcodebuild -license` 阅读条款。没有在本次工作中替你接受条款、修改系统开发者目录或安装模拟器运行时。

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

工程只申请 `user-read-currently-playing`，不申请控制、修改歌单或读取密码权限。网络轮询在前台每 3 秒一次，429 尊重 Retry-After，401 尝试一次刷新，403 明确显示账户/开发者权限错误。授权使用系统浏览器会话；令牌存在本机 Keychain。

## 灵动岛与 iPad 锁屏

在有灵动岛的 iPhone 上点击「开启灵动岛」。紧凑区域最多显示约 6 个字符；长按展开显示当前句、下一句和歌名。其他 iPhone 与 iPad 使用锁屏实时活动。iPad 没有灵动岛；设备和系统是否允许实时活动，以实际返回与系统设置为准。

实时活动前台更新与完整歌词窗口共用同一状态。后台需要推送。未设置推送桥时，歌词会保留最近一条，30 秒后进入等待更新状态；这是系统限制，不能当作后台逐句同步。

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
