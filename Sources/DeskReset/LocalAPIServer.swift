import Foundation
import DeskResetCore

struct APIHTTPResponse {
    var status: Int
    var body: [String: Any]
}

final class LocalAPIServer: @unchecked Sendable {
    typealias Handler = @MainActor (APICommand, Data?) -> APIHTTPResponse

    private let handler: Handler
    private let queue = DispatchQueue(label: "deskreset.local-api", qos: .utility)
    private var socketFD: Int32 = -1
    private var running = false

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start(port: Int) throws {
        stop()

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw APIError.socket(errno)
        }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw APIError.bind(errno)
        }
        guard listen(fd, 16) == 0 else {
            close(fd)
            throw APIError.listen(errno)
        }

        socketFD = fd
        running = true
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        running = false
        if socketFD >= 0 {
            shutdown(socketFD, SHUT_RDWR)
            close(socketFD)
            socketFD = -1
        }
    }

    private func acceptLoop() {
        while running {
            let client = accept(socketFD, nil, nil)
            if client >= 0 {
                handle(client: client)
            }
        }
    }

    private func handle(client: Int32) {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0 else {
            close(client)
            return
        }

        var data = Data(buffer.prefix(count))
        while let expected = contentLength(in: data), bodyLength(in: data) < expected {
            let next = recv(client, &buffer, buffer.count, 0)
            guard next > 0 else { break }
            data.append(contentsOf: buffer.prefix(next))
        }
        let request = parseRequest(data)

        let handler = handler
        Task { @MainActor in
            let response: APIHTTPResponse
            if let request, let command = APIRouter.command(method: request.method, path: request.path) {
                response = handler(command, request.body)
            } else {
                response = APIHTTPResponse(status: 404, body: ["ok": false, "error": "unknown_route"])
            }
            LocalAPIServer.write(response: response, to: client)
        }
    }

    private func parseRequest(_ data: Data) -> HTTPRequest? {
        guard
            let text = String(data: data, encoding: .utf8),
            let headerRange = text.range(of: "\r\n\r\n")
        else {
            return nil
        }

        let header = String(text[..<headerRange.lowerBound])
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let bodyStart = text[headerRange.upperBound...]
        let body = bodyStart.isEmpty ? nil : Data(String(bodyStart).utf8)
        return HTTPRequest(method: String(parts[0]), path: String(parts[1]), body: body)
    }

    private func contentLength(in data: Data) -> Int? {
        guard
            let text = String(data: data, encoding: .utf8),
            let headerRange = text.range(of: "\r\n\r\n")
        else {
            return nil
        }
        let header = text[..<headerRange.lowerBound]
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1])
            }
        }
        return nil
    }

    private func bodyLength(in data: Data) -> Int {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return 0 }
        return data.distance(from: range.upperBound, to: data.endIndex)
    }

    private static func write(response: APIHTTPResponse, to client: Int32) {
        let payload = (try? JSONSerialization.data(withJSONObject: response.body, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        let reason = response.status == 200 ? "OK" : response.status == 400 ? "Bad Request" : "Not Found"
        let header = """
        HTTP/1.1 \(response.status) \(reason)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(payload.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: http://127.0.0.1\r
        \r

        """
        _ = header.withCString { send(client, $0, strlen($0), 0) }
        payload.withUnsafeBytes { rawBuffer in
            if let base = rawBuffer.baseAddress {
                _ = send(client, base, payload.count, 0)
            }
        }
        close(client)
    }

    deinit {
        stop()
    }
}

private struct HTTPRequest {
    var method: String
    var path: String
    var body: Data?
}

enum APIError: Error, CustomStringConvertible {
    case socket(Int32)
    case bind(Int32)
    case listen(Int32)

    var description: String {
        switch self {
        case .socket(let code): return "socket failed: \(code)"
        case .bind(let code): return "bind failed: \(code)"
        case .listen(let code): return "listen failed: \(code)"
        }
    }
}
