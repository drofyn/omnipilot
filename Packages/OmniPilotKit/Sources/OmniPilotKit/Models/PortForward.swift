import Foundation

public enum ForwardKind: String, Hashable, Sendable {
    case local
    case remote

    public var label: String {
        switch self {
        case .local: return "本地转发"
        case .remote: return "远程转发"
        }
    }

    public var shortLabel: String {
        switch self {
        case .local: return "L"
        case .remote: return "R"
        }
    }
}

/// A single forwarding rule declared for a host (`LocalForward` / `RemoteForward`).
public struct PortForward: Hashable, Sendable, Identifiable {
    public let kind: ForwardKind
    public let bind: PortSpec
    public let target: PortSpec

    public init(kind: ForwardKind, bind: PortSpec, target: PortSpec) {
        self.kind = kind
        self.bind = bind
        self.target = target
    }

    public var id: String {
        "\(kind.rawValue)|\(bind)|\(target)"
    }

    public var display: String {
        "\(bind) → \(target)"
    }
}
