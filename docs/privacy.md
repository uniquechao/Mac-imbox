# Mac-imbox 隐私政策 / Privacy policy

开发者 / Developer · xschao

## 中文

消息板在你的 Mac 上处理所选应用的标识、安装路径、运行状态和未读角标。它从 Dock 或菜单栏读取应用公开的数字，用于计算总数和打开首个有未读的应用。消息板不读取聊天正文、联系人或聊天记录。

你允许辅助功能访问后，消息板还可以操作「系统设置」中的菜单栏开关，以及执行所选应用支持的菜单命令。为显示 Clash Party 的状态图标，它会在本机读取该应用的配置。应用选择、待同步操作和使用指引状态保存在本机；同步错误可能记入本机系统日志。

消息板没有账号、广告或分析 SDK，也不会把上述信息传给开发者。启用「自动检查更新」后，消息板定期向 GitHub 请求最新公开版本。GitHub 会收到 IP 地址等连接信息，请求不包含应用列表或未读数。点击 GitHub 链接会在浏览器中访问 GitHub，受其隐私政策约束。

可在面板中移除应用，或到「系统设置 → 隐私与安全性」撤销消息板的辅助功能权限。若要清除本机的消息板偏好，请先恢复你想保留的原菜单栏图标，退出消息板，再在终端执行 `defaults delete com.xschao.MessageBoard`。隐私问题可通过[支持页面](support.md)联系开发者。

## English

Mac-imbox processes selected app identifiers, installation paths, running status and numeric badges on your Mac. It reads counts exposed by the Dock or menu bar to calculate the total and open the first app with unread messages. It does not read chat messages, contacts or conversation history.

With Accessibility access, Mac-imbox can operate menu bar switches in System Settings and invoke supported app menu commands. It reads local Clash Party configuration to choose a status icon. App selections, pending operations and guide preferences are stored locally. Sync errors may appear in local system logs.

Mac-imbox has no accounts, advertising or analytics SDKs. It does not send this information to the developer. If you enable automatic update checks, Mac-imbox periodically requests the latest public release from GitHub. GitHub receives connection information such as your IP address. The request excludes your app list and unread counts. Opening a GitHub link visits GitHub in your browser under GitHub’s privacy policy.

Remove apps in the panel or revoke Accessibility access in System Settings. To clear local preferences, first restore any original menu bar icons you want to keep, quit Mac-imbox, then run `defaults delete com.xschao.MessageBoard` in Terminal. For privacy questions, visit [Support](support.md).
