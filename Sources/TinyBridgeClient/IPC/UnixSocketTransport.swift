import Foundation
import Darwin

/// Errors surfaced by the low-level transport. These are deliberately distinct
/// from protocol errors so the UI can tell "the daemon isn't there" apart from
/// "the daemon said no".
public enum TransportError: Error, Equatable {
    case socketCreationFailed(errno: Int32)
    case pathTooLong(path: String)
    case connectFailed(path: String, errno: Int32)
    case sendFailed(errno: Int32)
    case receiveFailed(errno: Int32)
    case timedOut
    case connectionClosedBeforeResponse
    case malformedResponse(underlying: String)

    public var userMessage: String {
        switch self {
        case .socketCreationFailed(let e):
            return "Could not create a socket (errno \(e))."
        case .pathTooLong(let p):
            return "Socket path is too long: \(p)"
        case .connectFailed(let p, let e):
            if e == ENOENT || e == ECONNREFUSED {
                return "No TinyBridge daemon is listening at \(p). Start tinybridged, then retry."
            }
            return "Could not connect to \(p) (errno \(e))."
        case .sendFailed(let e):
            return "Failed to send the request (errno \(e))."
        case .receiveFailed(let e):
            return "Failed to read the response (errno \(e))."
        case .timedOut:
            return "The daemon did not respond in time. The operation may still be running."
        case .connectionClosedBeforeResponse:
            return "The daemon closed the connection before responding."
        case .malformedResponse(let detail):
            return "The daemon returned a response that could not be parsed: \(detail)"
        }
    }
}

/// A single request/response round-trip over a TinyBridge Unix-domain socket.
///
/// TinyBridge's CLI (`crates/tinybridge-cli/src/client.rs`) opens one
/// connection per call: write the JSON-RPC request plus `\n`, read one
/// newline-terminated response, close. This transport does exactly the same,
/// so it speaks the wire protocol the daemon already serves — no daemon
/// changes required.
public struct UnixSocketTransport: Sendable {
    public let path: String

    /// Maximum size of `sun_path` on Darwin (including the NUL terminator).
    private static let maxPathBytes = MemoryLayout.size(ofValue: sockaddr_un().sun_path)

    public init(path: String) {
        self.path = path
    }

    /// Perform one blocking round-trip. Callers must run this off the main
    /// actor (the client does).
    public func roundTrip(_ payload: Data, timeout: TimeInterval) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw TransportError.socketCreationFailed(errno: errno) }
        defer { close(fd) }

        try configureTimeouts(fd: fd, timeout: timeout)
        try connect(fd: fd)
        try sendAll(fd: fd, data: payload)
        return try readLine(fd: fd)
    }

    // MARK: - Steps

    private func configureTimeouts(fd: Int32, timeout: TimeInterval) throws {
        var tv = timeval(
            tv_sec: Int(timeout),
            tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000)
        )
        let size = socklen_t(MemoryLayout<timeval>.size)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, size)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, size)
    }

    private func connect(fd: Int32) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(path.utf8)
        guard pathBytes.count < Self.maxPathBytes else {
            throw TransportError.pathTooLong(path: path)
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Self.maxPathBytes) { chars in
                for (index, byte) in pathBytes.enumerated() {
                    chars[index] = CChar(bitPattern: byte)
                }
                chars[pathBytes.count] = 0
            }
        }

        let result = withUnsafePointer(to: &addr) { addrPointer in
            addrPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            throw TransportError.connectFailed(path: path, errno: errno)
        }
    }

    private func sendAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { raw -> Void in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let written = Darwin.send(
                    fd,
                    base.advanced(by: offset),
                    raw.count - offset,
                    0
                )
                if written <= 0 {
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        throw TransportError.timedOut
                    }
                    throw TransportError.sendFailed(errno: errno)
                }
                offset += written
            }
        }
    }

    private func readLine(fd: Int32) throws -> Data {
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.recv(fd, &buffer, buffer.count, 0)
            if count == 0 {
                break // peer closed
            }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw TransportError.timedOut
                }
                throw TransportError.receiveFailed(errno: errno)
            }
            if let newlineIndex = buffer[..<count].firstIndex(of: 0x0A) {
                out.append(contentsOf: buffer[..<newlineIndex])
                return out
            }
            out.append(contentsOf: buffer[..<count])
        }
        if out.isEmpty {
            throw TransportError.connectionClosedBeforeResponse
        }
        return out
    }
}
