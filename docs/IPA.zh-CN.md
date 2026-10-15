# iPhone/iPad 待签名 IPA

GitHub 图标预览版：[v0.1.1-icons](https://github.com/hhhoratioxu/VerseDock/releases/tag/v0.1.1-icons)。

`VerseDock-iOS-unsigned.ipa` 是从本项目完整编译出的 iOS 设备 App，包含实际的 arm64 主程序和 `VerseDockActivity.appex` 灵动岛/锁屏实时活动扩展。最低 iOS/iPadOS 17，支持 iPhone 和 iPad。它不是模拟器程序，也不是仅把源码改了后缀。

这个 IPA 没有 Apple 签名、个人证书或 provisioning profile。下载后需要使用你自己的 Apple 签名身份和描述文件重新签名，再安装到获准的设备。给文件添加本地临时签名不能替代 iOS 要求的 Apple 签名和描述文件。

## 下载与检查

下载发布附件中的：

- `VerseDock-iOS-unsigned.ipa`：待签名包。
- `VerseDock-iOS-unsigned.sha256`：包的 SHA-256。
- `VerseDock-iOS-BuildInfo.json`：源码提交、编译工具版本、两个可执行文件的架构与哈希、签名状态。

将 IPA 和 `.sha256` 放在同一个目录，用 `shasum -a 256 -c VerseDock-iOS-unsigned.sha256` 检查文件。签名会修改 IPA，签名后的文件不再匹配原始校验值。

## 自行签名时保留扩展

1. 将待签名 IPA 导入你使用的签名工具，使用你自己的 Apple 账号或证书、描述文件完成签名。私钥、Apple 密码和描述文件不需要上传到 GitHub。
2. 保留 `PlugIns/VerseDockActivity.appex`。如果工具删除所有扩展，App 本身即使能启动，也不会有这个灵动岛/锁屏实时活动。
3. 主 App 和扩展使用相同 Team；扩展的 Bundle ID 必须保留主 App ID 的前缀关系。若修改主 App ID，也要同步修改扩展 ID，并为两个 bundle 完成匹配的签名。
4. 签名并安装后，先运行 App 内的原创演示检查显示，再按照 `SETUP.zh-CN.md` 配置 Spotify Client ID 和你自己的 HTTPS 回调地址。
5. 灵动岛需要有相应硬件的 iPhone；iPad 使用锁屏实时活动。

普通账号或签名工具不一定保留所有 capability。前台歌词和本地实时活动不依赖后台 APNs，但远程推送桥需要签名配置允许 Push Notifications，且正确配置 `aps-environment`、服务端 APNs 密钥和相同的主 App Bundle ID。包已包含相关实现，不代表个人签名后一定能使用后台推送。

## 可重复构建

完整 Xcode、iPhoneOS SDK 和许可就绪后，在项目根目录执行：

```sh
zsh scripts/build-ios-unsigned.sh
```

脚本使用标准 `xcodebuild` 编译 Release 设备版本，明确关闭签名，再通过 `package-ios.py` 验证与打包。检查包括 iPhoneOS 平台、arm64 Mach-O、最低系统版本、可执行权限、主 App 和扩展的 ID/版本关系、WidgetKit 声明、Live Activity 开关、OAuth URL scheme、ZIP 完整性和签名材料排除。

构建日志保留在本地 `build/ios-build.log`，不上传含个人路径的原始日志。公开构建摘要在 `Evidence/ios-device-build.json`。打包成功不等于真机验收：本次没有签名证书，也没有安装到 iPhone/iPad，安装、授权、灵动岛实际布局和后台 APNs 送达仍待签名后的设备验证。

## Apple 官方签名资料

- [创建开发描述文件](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile)
- [分发到已注册设备](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
