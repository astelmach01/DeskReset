import Foundation

@main
struct DeskResetCtl {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let port = Int(ProcessInfo.processInfo.environment["DESKRESET_API_PORT"] ?? "") ?? 17777

        guard let command = args.first else {
            usage(exitCode: 1)
        }

        let request: APIRequest
        switch command {
        case "status":
            request = APIRequest(method: "GET", path: "/v1/status", body: nil)
        case "settings":
            request = APIRequest(method: "GET", path: "/v1/settings", body: nil)
        case "patch-settings":
            guard args.count >= 2 else { usage(exitCode: 1) }
            request = APIRequest(method: "PATCH", path: "/v1/settings", body: args[1])
        case "start":
            guard args.count >= 2, ["micro", "movement"].contains(args[1]) else { usage(exitCode: 1) }
            request = APIRequest(method: "POST", path: "/v1/breaks/start/\(args[1])", body: nil)
        case "done", "complete":
            request = APIRequest(method: "POST", path: "/v1/breaks/complete", body: nil)
        case "skip":
            request = APIRequest(method: "POST", path: "/v1/breaks/skip", body: nil)
        case "snooze":
            let minutes = args.count >= 2 ? args[1] : "5"
            request = APIRequest(method: "POST", path: "/v1/breaks/snooze?minutes=\(minutes)", body: nil)
        case "focus":
            let minutes = args.count >= 2 ? args[1] : "60"
            request = APIRequest(method: "POST", path: "/v1/focus?minutes=\(minutes)", body: nil)
        case "resume":
            request = APIRequest(method: "POST", path: "/v1/reminders/resume", body: nil)
        case "reset-stats":
            request = APIRequest(method: "POST", path: "/v1/stats/reset", body: nil)
        case "open-settings":
            request = APIRequest(method: "POST", path: "/v1/ui/settings", body: nil)
        case "open-onboarding":
            request = APIRequest(method: "POST", path: "/v1/ui/onboarding", body: nil)
        default:
            usage(exitCode: 1)
        }

        let url = URL(string: "http://127.0.0.1:\(port)\(request.path)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        if let body = request.body {
            urlRequest.httpBody = Data(body.utf8)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                fputs("deskresetctl: HTTP \(http.statusCode)\n", stderr)
                exit(3)
            }
            if !data.isEmpty {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        } catch {
            fputs("deskresetctl: \(error.localizedDescription)\n", stderr)
            exit(2)
        }
    }

    struct APIRequest {
        var method: String
        var path: String
        var body: String?
    }

    static func usage(exitCode: Int32) -> Never {
        let text = """
        Usage:
          deskresetctl status
          deskresetctl settings
          deskresetctl patch-settings '{"strictMode":true}'
          deskresetctl start micro|movement
          deskresetctl done
          deskresetctl skip
          deskresetctl snooze [minutes]
          deskresetctl focus [minutes]
          deskresetctl resume
          deskresetctl reset-stats
          deskresetctl open-settings
          deskresetctl open-onboarding

        Environment:
          DESKRESET_API_PORT defaults to 17777
        """
        fputs(text + "\n", stderr)
        exit(exitCode)
    }
}
