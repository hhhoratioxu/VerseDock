# 在线歌词与匹配

VerseDock 从 Spotify 读取歌曲和进度，再独立获取外部歌词。不读取 Spotify 客户端内部歌词、Cookie、密码或私有令牌。

## 来源与切换

1. LRCLIB：使用官方搜索接口按歌名/歌手找候选，统一繁简体后核对。专辑不是拒绝精选集或重发版本的唯一条件。
2. QQ 音乐：使用匿名网页服务搜索歌曲、核对歌手资料、读取时间轴歌词；中英文歌手别名从服务响应取得。这个网页接口没有稳定的第三方 API 承诺，变化或拒绝访问会显示为来源不可用并继续换源。
3. 网易云音乐：原创适配匿名网页搜索与时间轴歌词接口；按歌曲名称、歌手及服务返回的别名、版本和时长核对。它不是稳定承诺的公开开发者歌词 API，接口变化、地区或版权限制会影响可用性；不采用“原唱”标题替代对真实歌手的核对，不获取账号 Cookie。
4. lyrics.ovh：按歌手/歌名获取纯文本。仅做全文显示，不虚构同步时间戳。

默认保留「自动」；用户可以手动指定 LRCLIB、QQ 音乐、网易云或 lyrics.ovh，手动模式只访问所选服务。偏好自动保存，切换后跳过旧来源缓存重查当前歌曲；本地导入文件不会被其他提供商伪装。

一个来源无结果、超时、HTTP 错误或返回无效内容时继续下一个。纯文本会暂存，继续寻找同步版本；全部来源无同步版本时仍可显示已取得的纯文本。已尝试来源的结果在设置中展示，实际来源与来源链接显示在窗口底部。

请求使用 VerseDock 自身的 User-Agent，不传送 Spotify 授权，不下载音频，不依赖其他歌词插件源码。只向所尝试的歌词服务发送当前歌曲元数据。网络开关可随时关闭；已有本地导入文件优先，纯文本网络缓存可重新寻找同步版本。窗口顶部的重试按钮跳过缓存。服务和网络状态影响覆盖率，不能保证每首歌都有歌词。

## 防止错配

保留 Live、Remix、伴奏、不插电等版本标签；歌手集合必须一致，外文别名需要歌手资料确认。时长容差为 3 秒至 8 秒，随歌曲长度变化；超过 3 秒会显示具体差异并提供校准。更长剪辑、其他歌手和版本不符的候选会拒绝。容差表示可用的近似歌词匹配，不代表音频指纹验证或逐字精确对齐。

歌词权利属于各自权利人；本仓库不打包商业歌曲歌词。公开测试证据只记录元数据、来源、行数、时间范围和请求结果，不保存歌词全文。

## 可重复检查

`scripts/probe-lyrics.swift` 使用与 App 相同的 Swift 客户端，向实际服务请求并输出不含歌词正文的摘要。参数为歌名、歌手、专辑、秒数和可选来源 `lrclib` / `qqMusic` / `netEase` / `lyricsOVH`。核心测试另用原创歌词与网络替身验证 404、503、限流、取消、纯文本降级、QQ 备用源、别名确认和滚动窗口；替身测试不等于真实服务成功。

接口说明：[LRCLIB 官方文档](https://lrclib.net/docs)、[lyrics.ovh 官方接口说明](https://lyricsovh.docs.apiary.io/)、[QQ 音乐](https://y.qq.com/)。这些资料用于独立实现请求和解析，不复制其他应用实现。

## Spotify 原词、YouTube Music 与 Apple Music

用户期望的顺序是“先 Spotify 原词，无词后再选择备用来源”。当前未实现这个首选判断：Spotify 官方答复没有公开的歌词 API，当前 Web API 的歌曲响应也没有歌词正文或可靠的歌词可用性字段。Spotify 客户端有歌词不表示 VerseDock 的播放授权能读取它。当前只实现已核验的备用来源，不伪造 Spotify 成功、无歌词或自动判断记录，也不要求提供 Spotify Cookie/密码。

YouTube Data API 的字幕下载需要对视频有编辑权限的授权，不能作为任意歌曲的通用歌词服务。Apple Music 的公开 `hasLyrics` 是可用性布尔值，没有在本版本取得歌词正文。它们尚未接通，不列入可选的可用提供商。

依据：[Spotify 官方答复](https://community.spotify.com/forum/en/discussion/5355493/update-endpoint-for-lyrics)、[Spotify 当前播放响应](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track)、[YouTube 官方字幕下载](https://developers.google.com/youtube/v3/docs/captions/download)、[Apple Music hasLyrics](https://developer.apple.com/documentation/musickit/song/haslyrics)。

## 可选机器翻译

默认关闭，用户自行选择开关和目标语言。Translation 框架提供的语言列表以本机实时结果为准，不能把界面上的语言数量解释成所有语言组合都可互译。初次使用需要系统语言包；不支持、用户取消或翻译失败时继续显示原词并给出提示。旧系统保留歌词功能，翻译提示最低版本 macOS 15 / iOS/iPadOS 18。

原创代码按文本去重，以请求标识和原文共同验证响应身份，按原时间戳显示译文。切歌、目标语言或开关变化会失效旧任务；重复歌词共享结果，异步返回顺序不影响对应关系。QQ/网易云提供的附加译文不会在默认关闭时混入原词。机器翻译不是官方歌词译文，也不保证文学或语境准确。

系统翻译的实际调用与语言能力可用 `scripts/probe-translation.swift` 复查。它只使用已安装的语言包翻译项目原创示例，不替用户批准下载。公开摘要见 `Evidence/translation-system.json`。依据：[Apple Translation](https://developer.apple.com/documentation/translation/translating-text-within-your-app)。
