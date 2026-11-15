//
//  DecadeProxyManager.swift
//  J2MEEmulator
//
//  1:1 Replica of Decade APK Proxy System:
//  - Proxy Storage & CRUD (SOCKS5 & HTTP with Auth)
//  - Multi-line Bulk Import (ip:port:user:pass)
//  - Real-time Connection Testing & Latency (ms) Measurement
//  - Per-Tab Proxy Routing & Assignment
//  - Immediate Socket Disconnect to trigger in-game reconnect
//

import UIKit
import Network

// ============================================================
// MARK: - Data Models
// ============================================================

struct ProxyItem: Codable, Equatable {
    let id: Int
    var type: String       // "socks5" or "http"
    var host: String
    var port: Int
    var user: String
    var pass: String
    var label: String
    var lastLatencyMs: Int?
    var lastTestStatus: String?

    var isSocks5: Bool { type.lowercased() == "socks5" }
    var hasAuth: Bool { !user.isEmpty }

    var displayTitle: String {
        return label.isEmpty ? "\(host):\(port)" : label
    }

    var displaySubtitle: String {
        var parts: [String] = []
        parts.append(isSocks5 ? "SOCKS5" : "HTTP")
        if hasAuth {
            parts.append("👤 \(user)")
        } else {
            parts.append("Không mật khẩu")
        }
        if let lat = lastLatencyMs, lat > 0 {
            parts.append("⚡ \(lat)ms")
        } else if let status = lastTestStatus {
            parts.append("⚠️ \(status)")
        }
        return parts.joined(separator: " • ")
    }
}

// ============================================================
// MARK: - DecadeProxyManager
// ============================================================

class DecadeProxyManager {
    static let shared = DecadeProxyManager()

    private let fileURL: URL
    private(set) var proxies: [ProxyItem] = []
    private var nextId: Int = 1

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("decade_proxies.json")
        loadProxies()
    }

    // MARK: - Persistence

    func loadProxies() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([ProxyItem].self, from: data) else {
            proxies = []
            return
        }
        proxies = list
        nextId = (proxies.map { $0.id }.max() ?? 0) + 1
    }

    func saveProxies() {
        if let data = try? JSONEncoder().encode(proxies) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - CRUD

    func addProxy(type: String, host: String, port: Int, user: String = "", pass: String = "", label: String? = nil) -> ProxyItem {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? label!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "\(cleanHost):\(port)"

        let item = ProxyItem(
            id: nextId,
            type: type.lowercased(),
            host: cleanHost,
            port: port,
            user: user.trimmingCharacters(in: .whitespacesAndNewlines),
            pass: pass,
            label: cleanLabel,
            lastLatencyMs: nil,
            lastTestStatus: nil
        )
        nextId += 1
        proxies.append(item)
        saveProxies()
        return item
    }

    func updateProxy(_ item: ProxyItem) {
        if let idx = proxies.firstIndex(where: { $0.id == item.id }) {
            proxies[idx] = item
            saveProxies()
        }
    }

    func deleteProxy(id: Int) {
        proxies.removeAll { $0.id == id }
        saveProxies()

        // Remove from tab assignments
        let ud = UserDefaults.standard
        for slot in 0..<16 {
            let key = "decade_tab_proxy_\(slot)"
            if ud.integer(forKey: key) == id {
                ud.removeObject(forKey: key)
                applyProxy(to: slot)
            }
        }
    }

    // MARK: - Bulk Import

    func importBulk(text: String) -> Int {
        return importProxies(text: text)
    }

    func importProxies(text: String, defaultType: String = "socks5") -> Int {
        let lines = text.components(separatedBy: .newlines)
        var count = 0

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }

            var curType = defaultType.lowercased()
            var body = line

            if body.hasPrefix("socks5://") {
                curType = "socks5"
                body = String(body.dropFirst(9))
            } else if body.hasPrefix("http://") {
                curType = "http"
                body = String(body.dropFirst(7))
            }

            // Formats supported:
            // 1. host:port
            // 2. host:port:user:pass
            // 3. user:pass@host:port
            var host = ""
            var port = 0
            var user = ""
            var pass = ""

            if body.contains("@") {
                let parts = body.components(separatedBy: "@")
                if parts.count == 2 {
                    let auth = parts[0].components(separatedBy: ":")
                    user = auth.first ?? ""
                    pass = auth.count > 1 ? auth[1] : ""
                    let hp = parts[1].components(separatedBy: ":")
                    host = hp.first ?? ""
                    port = Int(hp.count > 1 ? hp[1] : "") ?? 0
                }
            } else {
                let parts = body.components(separatedBy: ":")
                if parts.count >= 2 {
                    host = parts[0]
                    port = Int(parts[1]) ?? 0
                    if parts.count >= 4 {
                        user = parts[2]
                        pass = parts[3]
                    }
                }
            }

            if !host.isEmpty && port > 0 && port <= 65535 {
                _ = addProxy(type: curType, host: host, port: port, user: user, pass: pass)
                count += 1
            }
        }

        return count
    }

    // MARK: - Testing Connection & Latency

    func testProxy(item: ProxyItem, completion: @escaping (Bool, Int?, String?) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let host = NWEndpoint.Host(item.host)
        guard let port = NWEndpoint.Port(rawValue: UInt16(item.port)) else {
            completion(false, nil, "Cổng không hợp lệ")
            return
        }

        let params = NWParameters.tcp
        params.prohibitExpensivePaths = false
        let connection = NWConnection(host: host, port: port, using: params)

        var finished = false
        let queue = DispatchQueue(label: "decade.proxy.test")

        connection.stateUpdateHandler = { [weak self] state in
            guard !finished else { return }
            switch state {
            case .ready:
                finished = true
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                connection.cancel()

                DispatchQueue.main.async {
                    if var updated = self?.proxies.first(where: { $0.id == item.id }) {
                        updated.lastLatencyMs = elapsedMs
                        updated.lastTestStatus = "OK (\(elapsedMs)ms)"
                        self?.updateProxy(updated)
                    }
                    completion(true, elapsedMs, nil)
                }

            case .failed(let err):
                finished = true
                connection.cancel()
                DispatchQueue.main.async {
                    if var updated = self?.proxies.first(where: { $0.id == item.id }) {
                        updated.lastTestStatus = "Lỗi kết nối"
                        self?.updateProxy(updated)
                    }
                    completion(false, nil, err.localizedDescription)
                }

            case .waiting(let err):
                finished = true
                connection.cancel()
                DispatchQueue.main.async {
                    completion(false, nil, "Chờ timeout: \(err.localizedDescription)")
                }

            default:
                break
            }
        }

        connection.start(queue: queue)

        // 6 second timeout
        queue.asyncAfter(deadline: .now() + 6.0) {
            if !finished {
                finished = true
                connection.cancel()
                DispatchQueue.main.async {
                    completion(false, nil, "Quá thời gian kết nối (Timeout 6s)")
                }
            }
        }
    }

    // MARK: - Per-Tab Assignment

    func getProxyId(for slot: Int) -> Int {
        return UserDefaults.standard.integer(forKey: "decade_tab_proxy_\(slot)")
    }

    func getProxy(for slot: Int) -> ProxyItem? {
        let pid = getProxyId(for: slot)
        guard pid > 0 else { return nil }
        return proxies.first { $0.id == pid }
    }

    func assignProxy(slot: Int, proxyId: Int?) {
        let key = "decade_tab_proxy_\(slot)"
        if let pid = proxyId, pid > 0 {
            UserDefaults.standard.set(pid, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        applyProxy(to: slot)
    }

    func setProxyForSlot(_ slot: Int, proxy: ProxyItem?) {
        assignProxy(slot: slot, proxyId: proxy?.id)
    }

    func applyProxy(to slot: Int) {
        if let proxy = getProxy(for: slot) {
            let ptype: Int32 = proxy.isSocks5 ? 0 : 1
            proxy.host.withCString { hCstr in
                proxy.user.withCString { uCstr in
                    proxy.pass.withCString { pCstr in
                        jvm_bridge_set_slot_proxy(
                            Int32(slot),
                            ptype,
                            hCstr,
                            Int32(proxy.port),
                            uCstr,
                            pCstr
                        )
                    }
                }
            }
        } else {
            // Direct connection
            jvm_bridge_set_slot_proxy(Int32(slot), -1, nil, 0, nil, nil)
        }
    }

    func disconnectActiveSockets(for slot: Int) {
        jvm_bridge_disconnect_slot_sockets(Int32(slot))
    }
}
