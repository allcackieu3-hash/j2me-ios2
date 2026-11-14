import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        loadLocalContent()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = false

        view.addSubview(webView)
    }

    private func loadLocalContent() {
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "Web") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            let baseDir = htmlUrl.deletingLastPathComponent()
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: baseDir)
        } else if let resourceURL = Bundle.main.resourceURL {
            let directUrl = resourceURL.appendingPathComponent("Web/index.html")
            if FileManager.default.fileExists(atPath: directUrl.path) {
                webView.loadFileURL(directUrl, allowingReadAccessTo: resourceURL)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }
}
