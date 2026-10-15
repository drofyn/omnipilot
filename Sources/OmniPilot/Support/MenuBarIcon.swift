import AppKit

/// 菜单栏状态图标。
///
/// 由 `Design/OmniPilot.svg`（正常态）与 `Design/OmniPilotError.svg`（失败态）
/// 经 `Scripts/make-icon.sh` 生成，以 **模板图** 方式使用：macOS 只取 alpha
/// 通道并随浅色/深色菜单栏自动反色。
enum MenuBarIcon {
    static let size = NSSize(width: 18, height: 18)

    /// 正常态图标。
    static var image: NSImage? {
        templateImage(named: "MenuBarIcon")
    }

    /// 失败态图标（菱形中镂空感叹号）。
    static var errorImage: NSImage? {
        templateImage(named: "MenuBarIconError")
    }

    private static func templateImage(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = size
        return image
    }
}

/// 彩色应用图标，用于需要保留品牌色的地方（面板头部、关于页）。
enum AppIcon {
    static var image: NSImage {
        NSApp.applicationIconImage
    }
}
