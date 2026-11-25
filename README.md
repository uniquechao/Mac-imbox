# Mac-imbox

Mac-imbox 将微信、企业微信、飞书等通讯应用收进 macOS 菜单栏，汇总应用提供的未读数。左键展开面板，右键打开首个有未读消息的应用。

Mac-imbox groups messaging apps in the macOS menu bar and shows their combined unread count. Click to choose an app, or right-click to open the first one with unread messages.

## 本地构建 · Build locally

在安装了 Swift 工具链的 Mac 上运行以下命令。Run these commands on a Mac with the Swift toolchain installed.

```sh
./build.sh
open ./消息板.app
```

点 **＋** 添加应用，或点 **导入 IM** 批量加入已安装的常用通讯软件。在系统设置中授权消息板使用辅助功能后，运行中的应用会自动刷新角标。仅在应用内显示的未读数可能无法读取。

Use **＋** to add an app, or **导入 IM** to import supported messaging apps. Grant Accessibility access in System Settings to refresh badges for running apps. Counts shown only inside an app may be unavailable.

## License

[Apache License 2.0](LICENSE)
