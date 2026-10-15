import Foundation

public enum TunnelState: String, Sendable, Equatable {
    case stopped
    case starting
    case running
    case retrying
    case stopping
    case failed

    /// Whether the tunnel is expected to have a live process.
    public var isActive: Bool {
        switch self {
        case .starting, .running, .retrying:
            return true
        case .stopped, .stopping, .failed:
            return false
        }
    }

    public var label: String {
        switch self {
        case .stopped: return "已停止"
        case .starting: return "启动中"
        case .running: return "运行中"
        case .retrying: return "重连中"
        case .stopping: return "停止中"
        case .failed: return "失败"
        }
    }
}
