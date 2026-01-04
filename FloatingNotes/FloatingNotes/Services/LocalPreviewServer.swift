import Foundation
import Network

/// Lightweight HTTP server for previewing the web viewer locally
class LocalPreviewServer: ObservableObject {
    static let shared = LocalPreviewServer()

    private var listener: NWListener?
    private let port: UInt16 = 8765
    private var servingFolder: URL?

    @Published private(set) var isRunning: Bool = false

    var url: URL? {
        isRunning ? URL(string: "http://localhost:\(port)") : nil
    }

    func start(servingFolder: URL? = nil) {
        guard !isRunning else { return }

        // Use sync folder or default to app support
        if let folder = servingFolder {
            self.servingFolder = folder
        } else if let syncPath = ConfigurationManager.shared.config.sync.folderPath {
            self.servingFolder = URL(fileURLWithPath: syncPath)
        } else {
            // Default to local notes folder
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.servingFolder = appSupport.appendingPathComponent("FloatingNotes")
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self?.isRunning = true
                    }
                case .failed, .cancelled:
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                default:
                    break
                }
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("Failed to start preview server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }

            if let request = String(data: data, encoding: .utf8) {
                let response = self.handleRequest(request)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                connection.cancel()
            }
        }
    }

    private func handleRequest(_ request: String) -> Data {
        // Parse HTTP request
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return buildResponse(statusCode: 400, statusText: "Bad Request", body: "Invalid request")
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return buildResponse(statusCode: 400, statusText: "Bad Request", body: "Invalid request line")
        }

        let method = parts[0]
        var path = parts[1]

        // Only handle GET requests
        guard method == "GET" else {
            return buildResponse(statusCode: 405, statusText: "Method Not Allowed", body: "Only GET is supported")
        }

        // Remove query string
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }

        // URL decode path
        path = path.removingPercentEncoding ?? path

        // Handle root path
        if path == "/" {
            path = "/index.html"
        }

        // Serve file
        guard let folder = servingFolder else {
            return buildResponse(statusCode: 500, statusText: "Internal Server Error", body: "Server not configured")
        }

        // Prevent directory traversal
        let safePath = path.replacingOccurrences(of: "..", with: "")
        let filePath = folder.appendingPathComponent(String(safePath.dropFirst()))

        // Check if it's requesting the viewer
        if safePath == "/index.html" {
            return serveViewer()
        }

        // Serve static files
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return buildResponse(statusCode: 404, statusText: "Not Found", body: "File not found: \(safePath)")
        }

        guard let fileData = try? Data(contentsOf: filePath) else {
            return buildResponse(statusCode: 500, statusText: "Internal Server Error", body: "Failed to read file")
        }

        let contentType = mimeType(for: filePath.pathExtension)
        return buildResponse(statusCode: 200, statusText: "OK", contentType: contentType, body: fileData)
    }

    private func serveViewer() -> Data {
        // Generate viewer HTML with embedded index
        let html = WebViewerGenerator.shared.generateViewerHTML()
        return buildResponse(statusCode: 200, statusText: "OK", contentType: "text/html", body: html.data(using: .utf8) ?? Data())
    }

    private func buildResponse(statusCode: Int, statusText: String, contentType: String = "text/plain", body: String) -> Data {
        return buildResponse(statusCode: statusCode, statusText: statusText, contentType: contentType, body: body.data(using: .utf8) ?? Data())
    }

    private func buildResponse(statusCode: Int, statusText: String, contentType: String, body: Data) -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(body.count)\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"

        var responseData = response.data(using: .utf8) ?? Data()
        responseData.append(body)
        return responseData
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        default: return "application/octet-stream"
        }
    }
}
