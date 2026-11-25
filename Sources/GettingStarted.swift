import SwiftUI

enum MessagingApps {
    static let identifiers = [
        "com.tencent.xinWeChat", "com.tencent.WeWorkMac", "5ZSL2CJU2T.com.dingtalk.mac",
        "com.electron.lark", "com.tencent.qq", "com.tinyspeck.slackmacgap",
        "com.microsoft.teams2", "ru.keepcoder.Telegram", "org.telegram.desktop",
        "com.hnc.Discord", "net.whatsapp.WhatsApp", "org.whispersystems.signal-desktop",
        "cn.mininglamp.octo.work"
    ]
    static func installed() -> [URL] {
        identifiers.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }
}

struct GettingStarted: View {
    let finish: () -> Void
    @State private var step = 0
    private let pages = [
        ("plus", "加入应用", "点 ＋ 选择应用，或点「导入 IM」一次加入已安装的常用聊天软件。运行中的应用会出现在面板里。"),
        ("cursorarrow.click", "左键展开", "点菜单栏的消息板图标展开面板，再点应用图标打开它。长按图标可进入移除模式。"),
        ("arrow.turn.up.right", "右键直达未读", "右键点菜单栏图标，打开排在最前的有数字未读的应用。没有可读数字时展开面板。")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(pages[step].1, systemImage: pages[step].0).font(.headline)
            Text(pages[step].2).fixedSize(horizontal: false, vertical: true)
            HStack {
                if step > 0 { Button("上一步") { step -= 1 } }
                Spacer()
                Button(step == 2 ? "开始使用" : "下一步") {
                    if step == 2 { finish() } else { step += 1 }
                }
            }
        }.padding(8)
    }
}
