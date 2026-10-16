import Foundation

public enum ForwardKind: String, Hashable, Sendable {
    case local
    case remote
    case dynamic

    public var label: String {
        switch self {
        case .local: return "本地转发"
        case .remote: return "远程转发"
        case .dynamic: return "动态转发"
        }
    }

    public var shortLabel: String {
        switch self {
        case .local: return "L"
        case .remote: return "R"
        case .dynamic: return "D"
        }
    }
}

/// A single forwarding rule declared for a host (`LocalForward` / `RemoteForward` / `DynamicForward`).
public struct PortForward: Hashable, Sendable, Identifiable {
    public let kind: ForwardKind
    public let bind: PortSpec
    public let target: PortSpec?

    public init(kind: ForwardKind, bind: PortSpec, target: PortSpec? = nil) {
        self.kind = kind
        self.bind = bind
        self.target = target
    }

    public var id: String {
        if let target {
            return "\(kind.rawValue)|\(bind)|\(target)"
        }
        return "\(kind.rawValue)|\(bind)"
    }

    public var display: String {
        switch kind {
        case .local, .remote:
            if let target {
                return "\(bind) → \(target)"
            }
            return "\(bind)"
        case .dynamic:
            return "Socks5 \(bind.hostPortDescription)"
        }
    }
}
