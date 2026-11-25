# xschao 的 Mac-imbox 发布指南

## 先决定发布渠道

想让朋友或公众使用完整功能，可以继续在 GitHub Releases 提供 DMG。下一步是为官网发行版使用 **Developer ID Application** 签名并办理 Apple 公证。想让用户在 Mac App Store 搜到产品，需要单独准备启用 App Sandbox 的商店构建。这两条渠道使用不同的分发流程。

## 哪一步必须由本人做？

1. 在 [Apple Developer 账号](https://developer.apple.com/account/)检查 Membership。已有有效会员就使用现有团队；尚未加入且决定正式分发，再选择 Individual 注册。身份核验、协议和付款由账号本人完成。个人账号在商店展示法定姓名，应用内可署名 xschao。
2. 在 Xcode 的 Settings → Accounts 登录该 Apple Account，选择自己的付费团队。不要把密码、双重认证码、私钥或公证凭据发到 GitHub。
3. GitHub 正式分发使用 Developer ID Application 证书。在钥匙串配置 notarytool 凭据后，向 release-web.sh 提供证书名称和钥匙串配置名称。脚本会生成通用 DMG、提交公证并校验结果，成功后再发布。

## 商店版何时值得提交？

仓库中的 `scripts/build-sandbox-preview.sh` 创建独立 Bundle ID 的本机测试版，输出在 .build/sandbox-preview 下。它使用临时签名，仅供验证。正式版和测试版的辅助功能授权分别管理。

在测试 Mac 或专用 macOS 用户下验证以下实际操作。菜单栏开关属于当前系统用户，两个版本可能管理同一个开关。

| 验证 | 通过标准 |
| --- | --- |
| 添加与移除 | 添加一个有菜单栏图标的应用后原图标隐藏，移除后能恢复 |
| 未读数 | 用两个有数字角标的 IM 对比原始数字、面板各自的数字和顶部总数 |
| 右键 | 右键点顶部图标，排在前面的有未读应用成为前台 |
| 权限撤销 | 面板给出准确提示；重新授权后可以恢复 |

Apple 将辅助类应用使用 Accessibility API 列为沙盒不兼容情形。如果商店可用的能力不能支持这些操作，优先发布公证 DMG，或调整商店版功能与描述，再做商店验证。[Apple 沙盒说明](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)

## 通过功能验证后，准备商店记录

- 在开发者后台注册正式 Bundle ID，核实 com.xschao.MessageBoard 的归属，并在 App Store Connect 创建 macOS App 记录。使用正式团队做商店归档、验证和上传。
- 中英文名称可用「消息板 · Mac-imbox」和「Mac-imbox」，以后台名称可用性为准。副标题草案为「在菜单栏查看聊天应用未读数」和「Unread counts in your menu bar」。提交前按商店构建实测结果调整。
- 支持地址填 https://github.com/uniquechao/Mac-imbox/blob/main/docs/support.md ，隐私政策填 https://github.com/uniquechao/Mac-imbox/blob/main/docs/privacy.md 。
- 依据最终二进制填写 App Privacy、年龄分级、价格和销售地区。当前实现仅在本机处理数据；如果增加分析、网络服务或第三方 SDK，重新审核申报。
- 用最终商店构建在专用测试账号上截取静态截图。给审核员写清授权入口、如何加入应用、如何准备数字角标、怎么验证右键操作，以及没有可读角标时的表现。

[个人注册](https://developer.apple.com/help/account/membership/program-enrollment/) · [App Store Connect](https://appstoreconnect.apple.com/) · [审核指南](https://developer.apple.com/app-store/review/guidelines/)
