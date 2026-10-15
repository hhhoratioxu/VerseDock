# 在线歌词与匹配

**简体中文** · [English](LYRICS.en.md)

VerseDock 从 Spotify 读取歌曲和进度。开启原词优先并在隔离网页中登录后，先尝试 Spotify 网页原词，再按设置使用外部备用。不会读取 Spotify 桌面客户端的数据库或其他浏览器的登录资料。

## 来源与切换

1. LRCLIB：使用官方搜索接口按歌名/歌手找候选，统一繁简体后核对。专辑不是拒绝精选集或重发版本的唯一条件。
2. QQ 音乐：使用匿名网页服务搜索歌曲、核对歌手资料、读取时间轴歌词；中英文歌手别名从服务响应取得。这个网页接口没有稳定的第三方 API 承诺，变化或拒绝访问会显示为来源不可用并继续换源。
3. 网易云音乐：原创适配匿名网页搜索与时间轴歌词接口；按歌曲名称、歌手及服务返回的别名、版本和时长核对。它不是稳定承诺的公开开发者歌词 API，接口变化、地区或版权限制会影响可用性；不采用“原唱”标题替代对真实歌手的核对，不获取账号 Cookie。
4. lyrics.ovh：按歌手/歌名获取纯文本。仅做全文显示，不虚构同步时间戳。

备用默认保留「自动」；用户可以手动指定 LRCLIB、QQ 音乐、网易云或 lyrics.ovh，手动模式只访问所选备用。开启原词优先时，Spotify 仍先于手动备用。偏好自动保存，切换后跳过旧来源缓存重查当前歌曲；明确导入的本地文件仍优先，便于用户自行校正。

一个来源无结果、超时、HTTP 错误或返回无效内容时继续下一个。纯文本会暂存，继续寻找同步版本；全部来源无同步版本时仍可显示已取得的纯文本。已尝试来源的结果在设置中展示，实际来源与来源链接显示在窗口底部。

备用请求使用 VerseDock 自身的 User-Agent，不传送 Spotify 授权，不下载音频，不依赖其他歌词插件源码。只向所尝试的歌词服务发送当前歌曲元数据。网络开关可随时关闭；已有本地导入文件优先，纯文本网络缓存可重新寻找同步版本。开启原词优先时，外部缓存不会跳过 Spotify 检查。窗口顶部的重试按钮跳过缓存。服务和网络状态影响覆盖率，不能保证每首歌都有歌词。

## 防止错配

保留 Live、Remix、伴奏、不插电等版本标签；歌手集合必须一致，外文别名需要歌手资料确认。时长容差为 3 秒至 8 秒，随歌曲长度变化；超过 3 秒会显示具体差异并提供校准。更长剪辑、其他歌手和版本不符的候选会拒绝。容差表示可用的近似歌词匹配，不代表音频指纹验证或逐字精确对齐。

歌词权利属于各自权利人；本仓库不打包商业歌曲歌词。公开测试证据只记录元数据、来源、行数、时间范围和请求结果，不保存歌词全文。

## 可重复检查

`scripts/probe-lyrics.swift` 使用与 App 相同的 Swift 客户端，向实际服务请求并输出不含歌词正文的摘要。参数为歌名、歌手、专辑、秒数和可选来源 `lrclib` / `qqMusic` / `netEase` / `lyricsOVH`。核心测试另用原创歌词与网络替身验证 404、503、限流、取消、纯文本降级、QQ 备用源、别名确认和滚动窗口；替身测试不等于真实服务成功。

接口说明：[LRCLIB 官方文档](https://lrclib.net/docs)、[lyrics.ovh 官方接口说明](https://lyricsovh.docs.apiary.io/)、[QQ 音乐](https://y.qq.com/)。这些资料用于独立实现请求和解析，不复制其他应用实现。

## Spotify 原词、YouTube Music 与 Apple Music

0.1.3 增加可选的 Spotify 网页会话接入。Spotify 公开 Web API 仍不提供歌词；这里使用网页播放器的非公开 `color-lyrics` 接口，属于实验性功能。用户在「设置 → 连接 / 查看 Spotify 原词会话」中自行登录官方网页，Mac 使用独立标准窗口以保证键盘输入和焦点；也可点击「前往 Spotify 登录」直接进入账号页。本机已实际键入测试文字并清除，未提交测试账号。本机已完成真实账户验证：Spotify 返回《如果呢 / 郑润泽》42 行同步原词，来源标记 Spotify，原词提供方 Musixmatch，本次尝试记录只有 Spotify。《坏女孩 / 徐良》返回 404，Spotify 客户端同样显示无词，随后使用 LRCLIB。摘要见 `Evidence/spotify-original-live.json`，不含歌词正文或账号凭证。

原词优先默认开启：Spotify 返回有效的同步歌词或纯文本即采用，不再调用备用；404 或明确无可用正文才记录为 Spotify 无词。401/403 记录为授权不可用，网络错误、响应错误与 429 分别说明，并暂时走备用。关闭原词优先后只使用用户指定的备用方案。解析器不会给纯文本制造时间轴。

登录状态保存在本机独立的 WebKit 数据存储中，和 Safari、Chrome 及 Spotify 桌面 App 分离。原创建桥仅在 `https://open.spotify.com` 的主页面运行，利用该网页自身的第一方会话请求读取歌词。授权值留在页面闭包中；原生桥只接收就绪状态和经筛选的歌词数据。不会把 Cookie、密码、授权头或账号资料导出到 App 日志、备用歌词服务或 GitHub。清除登录会话只清除此隔离存储。

接口没有稳定性承诺，账户、地区、登录方式或网页更新可能导致不可用。网页会话的解析和降级策略已用原创数据测试，并另有上面的本机真实有词/无词结果；不据此保证其他账户、地区或所有歌曲可用。iOS 的相同 WebKit 路径已编译，未做真机登录验收。

YouTube Data API 的字幕下载需要对视频有编辑权限的授权，不能作为任意歌曲的通用歌词服务。Apple Music 的公开 `hasLyrics` 是可用性布尔值，没有在本版本取得歌词正文。它们尚未接通，不列入可选的可用提供商。

依据：[Spotify 官方答复](https://community.spotify.com/forum/en/discussion/5355493/update-endpoint-for-lyrics)、[Spotify 当前播放响应](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track)、[YouTube 官方字幕下载](https://developers.google.com/youtube/v3/docs/captions/download)、[Apple Music hasLyrics](https://developer.apple.com/documentation/musickit/song/haslyrics)。

## 点击歌词跳转

有时间轴的歌词行可以点击，原词或其下译文均属于同一按钮。跳转时间为该行时间减去用户保存的校准量，限制在 0 至歌曲结束前 0.05 秒，避免把末行误当作下一首。执行前校验仍是同一首歌，切歌或任务取消后丢弃旧结果。

Mac 通过固定 AppleScript 子程序和结构化参数设置真实 Spotify 的播放位置，随后读回歌曲与进度，只有实际位置接近目标才显示“已跳转”。本机实际点击《愛你但說不出口》的 0:38 行后，读回 Spotify 0:39，确认生效。不会把本地界面进度变化单独当作成功。

iOS 使用官方 `PUT /v1/me/player/seek`，先检查当前曲目身份；OAuth 新增 `user-modify-playback-state`，旧授权需要重新连接。Spotify 对此接口要求 Premium，失败会提示。此路径尚无真机账户控制验收。纯文本歌词没有准确时间戳，不能点击跳转。依据：[Spotify Seek to Position](https://developer.spotify.com/documentation/web-api/reference/seek-to-position-in-currently-playing-track)。

## 可选机器翻译

默认关闭，用户自行选择开关和目标语言。Translation 框架提供的语言列表以本机实时结果为准，不能把界面上的语言数量解释成所有语言组合都可互译。初次使用需要系统语言包；不支持、用户取消或翻译失败时继续显示原词并给出提示。旧系统保留歌词功能，翻译提示最低版本 macOS 15 / iOS/iPadOS 18。

原创代码按文本去重，以请求标识和原文共同验证响应身份，按原时间戳显示译文。切歌、目标语言或开关变化会失效旧任务；重复歌词共享结果，异步返回顺序不影响对应关系。QQ/网易云提供的附加译文不会在默认关闭时混入原词。机器翻译不是官方歌词译文，也不保证文学或语境准确。

系统翻译的实际调用与语言能力可用 `scripts/probe-translation.swift` 复查。它只使用已安装的语言包翻译项目原创示例，不替用户批准下载。公开摘要见 `Evidence/translation-system.json`。依据：[Apple Translation](https://developer.apple.com/documentation/translation/translating-text-within-your-app)。
