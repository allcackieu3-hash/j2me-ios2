import UIKit
import WebKit
import Network

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var connections: [Int: NWConnection] = [:]
    private let socketQueue = DispatchQueue(label: "com.decade.socketQueue", attributes: .concurrent)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
        setupWebView()
        loadLocalContent()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let contentController = WKUserContentController()
        contentController.add(self, name: "decadeNative")
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .clear
        webView.isOpaque = false

        view.addSubview(webView)
    }

    private func loadLocalContent() {
        // 1. Try finding index.html in Web folder reference
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            let baseDir = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: baseDir)
            return
        }

        // 2. Try finding index.html in root bundle
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: Bundle.main.bundleURL)
            return
        }

        // 3. Fallback: Direct HTML if bundle path resolution fails
        let fallbackHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { background: #0d0e12; color: #fff; font-family: -apple-system, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
                h1 { color: #ff2a5f; margin-bottom: 8px; }
                p { color: #94a3b8; font-size: 14px; max-width: 80%; }
                .btn { background: #ff2a5f; color: #fff; border: none; padding: 12px 24px; border-radius: 8px; font-weight: bold; margin-top: 16px; }
            </style>
        </head>
        <body>
            <h1>J2ME DECADE iOS</h1>
            <p>Hệ thống đã khởi động thành công trên iPhone của bạn.</p>
            <button class="btn" onclick="location.reload()">Tải Lại Giao Diện</button>
        </body>
        </html>
        """
        webView.loadHTMLString(fallbackHTML, baseURL: nil)
    }

    // MARK: - WKScriptMessageHandler (Native Socket Bridge)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "decadeNative",
              let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else {
            return
        }

        let socketId = dict["socketId"] as? Int ?? 0

        switch action {
        case "socketConnect":
            let host = dict["host"] as? String ?? ""
            let port = UInt16(dict["port"] as? Int ?? 80)
            let proxyHost = dict["proxyHost"] as? String
            let proxyPort = UInt16(dict["proxyPort"] as? Int ?? 0)
            let proxyType = dict["proxyType"] as? String ?? "DIRECT"
            connectSocket(socketId: socketId, host: host, port: port, proxyHost: proxyHost, proxyPort: proxyPort, proxyType: proxyType)

        case "socketSend":
            if let base64Data = dict["data"] as? String,
               let data = Data(base64Encoded: base64Data) {
                sendSocketData(socketId: socketId, data: data)
            }

        case "socketClose":
            closeSocket(socketId: socketId)

        default:
            break
        }
    }

    private func connectSocket(socketId: Int, host: String, port: UInt16, proxyHost: String?, proxyPort: UInt16, proxyType: String) {
        closeSocket(socketId: socketId)

        let targetHost: String
        let targetPort: UInt16
        let isProxy = (proxyType != "DIRECT" && proxyHost != nil && !proxyHost!.isEmpty && proxyPort > 0)

        if isProxy {
            targetHost = proxyHost!
            targetPort = proxyPort
        } else {
            targetHost = host
            targetPort = port
        }

        let endpointHost = NWEndpoint.Host(targetHost)
        guard let endpointPort = NWEndpoint.Port(rawValue: targetPort) else {
            notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'Invalid Port');")
            return
        }

        let params = NWParameters.tcp
        let connection = NWConnection(host: endpointHost, port: endpointPort, using: params)
        connections[socketId] = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if isProxy {
                    self.performProxyHandshake(socketId: socketId, connection: connection, proxyType: proxyType, destHost: host, destPort: port)
                } else {
                    self.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketOpen(\(socketId));")
                    self.receiveLoop(socketId: socketId, connection: connection)
                }
            case .failed(let error):
                self.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), '\(error.localizedDescription)');")
                self.closeSocket(socketId: socketId)
            case .cancelled:
                self.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketClose(\(socketId));")
            default:
                break
            }
        }

        connection.start(queue: socketQueue)
    }

    private func performProxyHandshake(socketId: Int, connection: NWConnection, proxyType: String, destHost: String, destPort: UInt16) {
        if proxyType == "HTTP" {
            // HTTP CONNECT Handshake
            let req = "CONNECT \(destHost):\(destPort) HTTP/1.1\r\nHost: \(destHost):\(destPort)\r\nProxy-Connection: Keep-Alive\r\n\r\n"
            guard let reqData = req.data(using: .utf8) else { return }

            connection.send(content: reqData, completion: .contentProcessed({ [weak self] error in
                if let error = error {
                    self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'Proxy Send Error: \(error.localizedDescription)');")
                    return
                }
                // Read HTTP response
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { (data, context, isComplete, error) in
                    if let data = data, let resp = String(data: data, encoding: .utf8), resp.contains("200") {
                        self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketOpen(\(socketId));")
                        self?.receiveLoop(socketId: socketId, connection: connection)
                    } else {
                        self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'HTTP Proxy Connect Failed');")
                        self?.closeSocket(socketId: socketId)
                    }
                }
            }))
        } else {
            // SOCKS5 Handshake
            // 1. Send version identifier/method selection: 0x05, 0x01, 0x00 (No auth)
            let greet = Data([0x05, 0x01, 0x00])
            connection.send(content: greet, completion: .contentProcessed({ [weak self] error in
                if let error = error {
                    self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'SOCKS5 Error: \(error.localizedDescription)');")
                    return
                }
                connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { (data, _, _, _) in
                    guard let data = data, data.count == 2, data[0] == 0x05, data[1] == 0x00 else {
                        self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'SOCKS5 Auth Failed');")
                        self?.closeSocket(socketId: socketId)
                        return
                    }

                    // 2. Send Connect Request: 0x05, 0x01 (connect), 0x00, 0x03 (domain), len, domain, port
                    var req = Data([0x05, 0x01, 0x00, 0x03])
                    let hostBytes = [UInt8](destHost.utf8)
                    req.append(UInt8(hostBytes.count))
                    req.append(contentsOf: hostBytes)
                    req.append(UInt8(destPort >> 8))
                    req.append(UInt8(destPort & 0xFF))

                    connection.send(content: req, completion: .contentProcessed({ _ in
                        connection.receive(minimumIncompleteLength: 4, maximumLength: 256) { (respData, _, _, _) in
                            if let resp = respData, resp.count >= 4, resp[1] == 0x00 {
                                self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketOpen(\(socketId));")
                                self?.receiveLoop(socketId: socketId, connection: connection)
                            } else {
                                self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), 'SOCKS5 Connect Failed');")
                                self?.closeSocket(socketId: socketId)
                            }
                        }
                    }))
                }
            }))
        }
    }

    private func receiveLoop(socketId: Int, connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { [weak self] (data, _, isComplete, error) in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                let base64 = data.base64EncodedString()
                self.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketData(\(socketId), '\(base64)');")
            }

            if isComplete {
                self.closeSocket(socketId: socketId)
            } else if error == nil {
                self.receiveLoop(socketId: socketId, connection: connection)
            } else if let error = error {
                self.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), '\(error.localizedDescription)');")
                self.closeSocket(socketId: socketId)
            }
        }
    }

    private func sendSocketData(socketId: Int, data: Data) {
        guard let connection = connections[socketId] else { return }
        connection.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketError(\(socketId), '\(error.localizedDescription)');")
            }
        }))
    }

    private func closeSocket(socketId: Int) {
        if let conn = connections[socketId] {
            conn.cancel()
            connections.removeValue(forKey: socketId)
            notifyJs(script: "window.DecadeNative && window.DecadeNative.onSocketClose(\(socketId));")
        }
    }

    private func notifyJs(script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Provisional navigation failed: \(error.localizedDescription)")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
