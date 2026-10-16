import Foundation

/// A single `[address:]port` endpoint inside an ssh forwarding rule.
///
/// `ssh -G` normalises forwarding specs into two tokens, for example:
///
///     localforward 4096 [127.0.0.1]:4096
///     localforward [127.0.0.1]:5000 [127.0.0.1]:5000
///
/// This type parses either form (`4096`, `127.0.0.1:4096`, `[::1]:4096`).
public struct PortSpec: Hashable, Sendable, CustomStringConvertible {
    public var address: String?
    public var port: Int

    public init(address: String? = nil, port: Int) {
        self.address = address
        self.port = port
    }

    public var description: String {
        if let address, !address.isEmpty {
            return "\(address):\(port)"
        }
        return "\(port)"
    }

    public var hostPortDescription: String {
        let resolvedAddress = (address?.isEmpty == false) ? address! : "127.0.0.1"
        if resolvedAddress.contains(":") {
            return "[\(resolvedAddress)]:\(port)"
        }
        return "\(resolvedAddress):\(port)"
    }

    public static func parse(_ raw: String) -> PortSpec? {
        let token = raw.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return nil }

        if token.hasPrefix("[") {
            guard let close = token.firstIndex(of: "]") else { return nil }
            let address = String(token[token.index(after: token.startIndex)..<close])
            let rest = token[token.index(after: close)...]
            guard rest.hasPrefix(":") else {
                return PortSpec(address: address.isEmpty ? nil : address, port: 0)
            }
            guard let port = Int(rest.dropFirst()) else { return nil }
            return PortSpec(address: address.isEmpty ? nil : address, port: port)
        }

        if let colon = token.lastIndex(of: ":") {
            let address = String(token[..<colon])
            guard let port = Int(token[token.index(after: colon)...]) else { return nil }
            return PortSpec(address: address.isEmpty ? nil : address, port: port)
        }

        guard let port = Int(token) else { return nil }
        return PortSpec(address: nil, port: port)
    }
}
