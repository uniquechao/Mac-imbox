# Mac-imbox

把常用聊天应用收进 Mac 菜单栏。左键展开面板，右键直达第一个有未读消息的应用。

Keep your messaging apps together in the Mac menu bar. Click to choose an app, or right-click to open the first one with unread messages.

[中文使用指南](#中文使用指南) · [English guide](#english-guide)

![操作示意：左键展开，两个应用分别有 9 和 1 条未读，顶部显示 10；右键打开排在前面的应用。Illustrated demo: two apps with 9 and 1 unread contribute to a total of 10.](docs/images/quick-tour.gif)

## 中文使用指南

1. **安装并打开。** 如果你拿到的是试用版 DMG，双击镜像，把「消息板」拖入「应用程序」，然后从那里启动。点屏幕顶部的消息板图标即可展开面板。
2. **加入聊天应用。** 点「导入 IM」一次加入本机已安装的受支持应用，例如微信、企业微信、飞书和钉钉。也可以点 **＋** 手动选择。已加入的应用退出后会从面板隐藏，下次启动时自动出现。
3. **启用未读角标。** 如果看到「无法读取未读数」，点「打开权限设置」，在 macOS 的「设备控制和数据访问」或「辅助功能」中允许「消息板」。回到面板等待约 3 秒，应用角标和顶部总数就会刷新。权限只需授予消息板。
4. **按需调整。** 长按面板中的应用图标，等图标晃动后点左上角 **×**，即可从消息板移除并恢复它的原菜单栏图标。点 **?** 可以随时重看使用指引。

| 点击哪里 | 左键 | 右键 / 双指点按 |
| --- | --- | --- |
| 顶部消息板图标 | 展开或收起面板 | 按面板顺序打开首个有未读的应用；没有可读数字时展开面板 |
| 面板里的应用图标 | 打开应用并切到前台 | 在原地弹出快捷菜单，可打开、移除；支持的应用还可直接打开设置 |

**为什么有消息却没有数字？** 消息板读取应用提供给 Dock 或可访问菜单栏项的数字。如果应用只闪烁图标，或只在聊天窗口内显示未读数，面板上的图标会保持空白。若原应用的 Dock 图标也没有数字，可检查「系统设置 → 通知 → 对应应用」中的「允许通知」和「标记应用程序图标」。

## English guide

1. **Install and open.** If you received a trial DMG, open it, drag **消息板** into **Applications**, and launch it from there. Click its icon at the top of your screen to open the panel.
2. **Add your apps.** Choose **导入 IM** (Import IM) to add supported messaging apps already installed on your Mac, including WeChat, WeCom, Feishu and DingTalk. Use **＋** to pick others manually. Apps disappear from the panel when they quit and return when you launch them again.
3. **Enable unread counts.** If the panel shows **无法读取未读数** (Unable to read unread counts), click **打开权限设置** (Open permission settings) and grant **消息板** Accessibility access in macOS. The panel badges and menu bar total refresh within about three seconds.
4. **Manage the panel.** Press and hold an app icon until it jiggles, then click **×** to remove it and restore its original menu bar icon. Click **?** to replay the guide.

| Where | Click | Right-click / two-finger click |
| --- | --- | --- |
| Mac-imbox menu bar icon | Open or close the panel | Open the first app in panel order with unread messages; open the panel if no count is available |
| App icon inside the panel | Bring the app to the foreground | Open a menu beside the icon to launch or remove the app, or open its settings when supported |

**Missing a badge?** Mac-imbox reads numeric counts exposed by an app through the Dock or an accessible menu bar item. Apps that only flash their icon or show unread counts inside a chat window may leave the badge blank. If the original Dock badge is also missing, check **System Settings → Notifications → the app** and look for **Allow notifications** and **Badge application icon**.
