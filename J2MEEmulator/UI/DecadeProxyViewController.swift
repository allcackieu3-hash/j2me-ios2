//
//  DecadeProxyViewController.swift
//  J2MEEmulator
//
//  1:1 Replica of Decade APK "Quản lý Proxy" & "Gán proxy cho tab":
//  - Danh Sách Proxy: CRUD, SOCKS5 & HTTP, Bulk Import, Latency Test
//  - Gán Proxy Cho Tab: Gán proxy cho từng tab game bên trong (Tab 1, Tab 2, Tab 3... Tab 27)
//    hoặc gán 1 proxy cho nhiều tab cùng lúc (chuẩn showTabPicker trong APK).
//

import UIKit

class DecadeProxyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let segmentedControl = UISegmentedControl(items: ["Danh Sách Proxy", "Gán Proxy Cho Tab"])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Current screen slot being configured (0 = Màn 1, 1 = Màn 2...)
    private var selectedScreenSlot: Int = 0

    // Initial segment to show
    var initialSegmentIndex: Int = 0

    private var proxies: [ProxyItem] {
        return DecadeProxyManager.shared.proxies
    }

    private var currentAppId: String {
        if let gvc = activeGameViewController, selectedScreenSlot < gvc.tabSessions.count {
            return gvc.tabSessions[selectedScreenSlot].appName
        }
        return "Game"
    }

    private var currentJarPath: String? {
        if let gvc = activeGameViewController, selectedScreenSlot < gvc.tabSessions.count {
            return gvc.tabSessions[selectedScreenSlot].jarPath
        }
        return activeGameViewController?.jarPath
    }

    private var currentMidletTabs: [MidletTab] {
        return MidletTabs.read(from: currentJarPath)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Quản lý Proxy"
        view.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)

        setupNavBar()
        setupUI()

        if initialSegmentIndex > 0 {
            segmentedControl.selectedSegmentIndex = initialSegmentIndex
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DecadeProxyManager.shared.loadProxies()
        tableView.reloadData()
    }

    private func setupNavBar() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 18, weight: .bold)]
        navigationController?.navigationBar.standardAppearance = navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(closeTapped))

        let addBtn = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addProxyTapped))
        let importBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(bulkImportTapped))
        navigationItem.rightBarButtonItems = [addBtn, importBtn]
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func setupUI() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProxyCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TabCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func segmentChanged() {
        tableView.reloadData()
    }

    // MARK: - Proxy CRUD Actions

    @objc private func addProxyTapped() {
        let alert = UIAlertController(title: "Thêm Proxy Mới", message: "Nhập thông tin máy chủ proxy:", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "IP / Tên miền (Host)" }
        alert.addTextField { tf in tf.placeholder = "Cổng (Port, vd: 1080 / 8080)"; tf.keyboardType = .numberPad }
        alert.addTextField { tf in tf.placeholder = "Tài khoản (Tùy chọn)" }
        alert.addTextField { tf in tf.placeholder = "Mật khẩu (Tùy chọn)"; tf.isSecureTextEntry = true }

        let socksAction = UIAlertAction(title: "Loại: SOCKS5", style: .default) { [weak self, weak alert] _ in
            self?.handleSaveProxy(alert: alert, type: "socks5")
        }
        let httpAction = UIAlertAction(title: "Loại: HTTP", style: .default) { [weak self, weak alert] _ in
            self?.handleSaveProxy(alert: alert, type: "http")
        }

        alert.addAction(socksAction)
        alert.addAction(httpAction)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func handleSaveProxy(alert: UIAlertController?, type: String) {
        guard let fields = alert?.textFields,
              let host = fields[0].text?.trimmingCharacters(in: .whitespaces), !host.isEmpty,
              let portStr = fields[1].text?.trimmingCharacters(in: .whitespaces), let port = Int(portStr) else {
            return
        }
        let user = fields[2].text?.trimmingCharacters(in: .whitespaces) ?? ""
        let pass = fields[3].text ?? ""

        _ = DecadeProxyManager.shared.addProxy(type: type, host: host, port: port, user: user, pass: pass)
        tableView.reloadData()
    }

    @objc private func bulkImportTapped() {
        let alert = UIAlertController(
            title: "Nhập Proxy Hàng Loạt",
            message: "Dán danh sách proxy theo định dạng:\nhost:port hoặc host:port:user:pass (mỗi dòng 1 proxy)",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Dán proxy tại đây..."
        }
        alert.addAction(UIAlertAction(title: "Nhập SOCKS5", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            let count = DecadeProxyManager.shared.importProxies(text: text, defaultType: "socks5")
            self?.tableView.reloadData()
            self?.showToast("Đã nhập thành công \(count) proxy SOCKS5!")
        })
        alert.addAction(UIAlertAction(title: "Nhập HTTP", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            let count = DecadeProxyManager.shared.importProxies(text: text, defaultType: "http")
            self?.tableView.reloadData()
            self?.showToast("Đã nhập thành công \(count) proxy HTTP!")
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast.dismiss(animated: true) }
    }

    // MARK: - TableView DataSource & Delegate

    func numberOfSections(in tableView: UITableView) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return 1
        } else {
            // Section 0: Proxy mặc định của màn
            // Section 1: Proxy riêng từng tab game
            return 2
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return proxies.count
        } else {
            if section == 0 {
                return 1 // Màn default proxy
            } else {
                return 1 + currentMidletTabs.count // 1 action row + tabs
            }
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if segmentedControl.selectedSegmentIndex == 0 {
            return "Danh Sách Proxy Đã Lưu (\(proxies.count))"
        } else {
            if section == 0 {
                let screenName = (activeGameViewController?.tabSessions.count ?? 1) > 1
                    ? "Màn \(selectedScreenSlot + 1): \(currentAppId)"
                    : "\(currentAppId)"
                return "Proxy Mặc Định — \(screenName)"
            } else {
                return "Proxy Riêng Từng Tab Game (\(currentMidletTabs.count) Tab)"
            }
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if segmentedControl.selectedSegmentIndex == 1 && section == 1 {
            return "Mỗi tab game (Tab 1, Tab 2, Tab 3...) sẽ chạy trên một địa chỉ IP mạng riêng biệt để tránh trùng IP khi đăng nhập game."
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segmentedControl.selectedSegmentIndex == 0 {
            // Segment 0: Proxy List
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProxyCell", for: indexPath)
            let item = proxies[indexPath.row]

            var config = cell.defaultContentConfiguration()
            config.text = item.displayTitle
            config.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)
            config.secondaryText = item.displaySubtitle
            config.secondaryTextProperties.font = .systemFont(ofSize: 13)
            config.secondaryTextProperties.color = .secondaryLabel
            config.image = UIImage(systemName: item.isSocks5 ? "lock.shield.fill" : "network")
            config.imageProperties.tintColor = item.isSocks5 ? UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0) : .systemGreen

            cell.contentConfiguration = config
            cell.accessoryType = .detailDisclosureButton
            return cell
        } else {
            // Segment 1: Tab Proxy Assignment
            if indexPath.section == 0 {
                // Section 0: Screen default proxy
                let cell = tableView.dequeueReusableCell(withIdentifier: "TabCell", for: indexPath)
                let assignedScreenProxy = DecadeProxyManager.shared.proxyForScreen(appId: currentAppId, slot: selectedScreenSlot)

                var config = cell.defaultContentConfiguration()
                config.text = "Proxy mặc định cho màn này"
                config.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)

                if let p = assignedScreenProxy {
                    config.secondaryText = "⚡ Đang dùng: \(p.displayTitle) (\(p.type.uppercased()))"
                    config.secondaryTextProperties.color = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
                    config.image = UIImage(systemName: "checkmark.shield.fill")
                    config.imageProperties.tintColor = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
                } else {
                    config.secondaryText = "🚫 Mặc định — không dùng proxy (Kết nối mạng trực tiếp)"
                    config.secondaryTextProperties.color = .secondaryLabel
                    config.image = UIImage(systemName: "circle")
                    config.imageProperties.tintColor = .systemGray
                }

                cell.contentConfiguration = config
                cell.accessoryType = .disclosureIndicator
                return cell

            } else {
                // Section 1: Per-game-tab proxy
                if indexPath.row == 0 {
                    // Action button: Batch assign 1 proxy to multiple tabs
                    let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
                    var config = cell.defaultContentConfiguration()
                    config.text = "⚡ Gán 1 proxy cho nhiều tab cùng lúc..."
                    config.textProperties.font = .systemFont(ofSize: 15, weight: .bold)
                    config.textProperties.color = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
                    config.image = UIImage(systemName: "square.grid.3x3.topleft.filled")
                    config.imageProperties.tintColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
                    cell.contentConfiguration = config
                    cell.accessoryType = .disclosureIndicator
                    return cell
                }

                let tabIndex = indexPath.row - 1
                let tab = currentMidletTabs[tabIndex]
                let cell = tableView.dequeueReusableCell(withIdentifier: "TabCell", for: indexPath)

                let assignedTabProxy = DecadeProxyManager.shared.proxyForTab(appId: currentAppId, slot: selectedScreenSlot, tabPrefix: tab.prefix)

                var config = cell.defaultContentConfiguration()
                config.text = "Tab \(tab.index) — \(tab.name)  (Ký hiệu: \(tab.prefix))"
                config.textProperties.font = .systemFont(ofSize: 15, weight: .semibold)

                if let p = assignedTabProxy {
                    config.secondaryText = "⚡ Proxy: \(p.displayTitle) (\(p.type.uppercased()))"
                    config.secondaryTextProperties.color = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
                    config.image = UIImage(systemName: "checkmark.circle.fill")
                    config.imageProperties.tintColor = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
                } else {
                    config.secondaryText = "Dùng proxy mặc định của màn"
                    config.secondaryTextProperties.color = .secondaryLabel
                    config.image = UIImage(systemName: "circle")
                    config.imageProperties.tintColor = .systemGray
                }

                cell.contentConfiguration = config
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if segmentedControl.selectedSegmentIndex == 0 {
            // Test proxy latency
            let item = proxies[indexPath.row]
            showTestingIndicator(for: item)
        } else {
            if indexPath.section == 0 {
                // Pick screen default proxy
                showScreenProxyPicker()
            } else {
                if indexPath.row == 0 {
                    // Batch assign to multiple tabs
                    showBatchTabPicker()
                } else {
                    // Pick proxy for individual game tab
                    let tab = currentMidletTabs[indexPath.row - 1]
                    showIndividualTabProxyPicker(for: tab)
                }
            }
        }
    }

    // MARK: - Testing Proxy Latency

    private func showTestingIndicator(for item: ProxyItem) {
        let alert = UIAlertController(title: "Đang kiểm tra...", message: "Đang đo độ trễ tới \(item.displayTitle)...", preferredStyle: .alert)
        present(alert, animated: true)

        DecadeProxyManager.shared.testProxy(item: item) { [weak self, weak alert] success, latencyMs, error in
            alert?.dismiss(animated: true) {
                self?.tableView.reloadData()
                let resultTitle = success ? "Kết nối thành công" : "Kết nối thất bại"
                let resultMsg = success ? "Độ trễ: \(latencyMs ?? 0) ms" : (error ?? "Không thể kết nối tới proxy")
                let resAlert = UIAlertController(title: resultTitle, message: resultMsg, preferredStyle: .alert)
                resAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(resAlert, animated: true)
            }
        }
    }

    // MARK: - Screen Default Proxy Picker

    private func showScreenProxyPicker() {
        let sheet = UIAlertController(
            title: "Proxy Mặc Định — Màn \(selectedScreenSlot + 1)",
            message: "Chọn proxy mặc định cho màn này (các tab không gán riêng sẽ dùng proxy này):",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "🚫 Mặc định — không dùng proxy (Trực tiếp)", style: .default) { [weak self] _ in
            guard let self = self else { return }
            DecadeProxyManager.shared.assignScreen(appId: self.currentAppId, slot: self.selectedScreenSlot, proxyId: nil)
            self.tableView.reloadData()
            self.promptDisconnectActiveSockets()
        })

        for p in proxies {
            sheet.addAction(UIAlertAction(title: "⚡ \(p.displayTitle) (\(p.type.uppercased()))", style: .default) { [weak self] _ in
                guard let self = self else { return }
                DecadeProxyManager.shared.assignScreen(appId: self.currentAppId, slot: self.selectedScreenSlot, proxyId: p.id)
                self.tableView.reloadData()
                self.promptDisconnectActiveSockets()
            })
        }

        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Individual Tab Proxy Picker

    private func showIndividualTabProxyPicker(for tab: MidletTab) {
        let sheet = UIAlertController(
            title: "Gán Proxy cho Tab \(tab.index) — \(tab.name)",
            message: "Chọn proxy áp dụng riêng cho tab game này:",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "Dùng proxy mặc định của màn", style: .default) { [weak self] _ in
            guard let self = self else { return }
            DecadeProxyManager.shared.assignTab(appId: self.currentAppId, slot: self.selectedScreenSlot, tabPrefix: tab.prefix, proxyId: nil)
            self.tableView.reloadData()
            self.promptDisconnectActiveSockets()
        })

        for p in proxies {
            sheet.addAction(UIAlertAction(title: "⚡ \(p.displayTitle) (\(p.type.uppercased()))", style: .default) { [weak self] _ in
                guard let self = self else { return }
                DecadeProxyManager.shared.assignTab(appId: self.currentAppId, slot: self.selectedScreenSlot, tabPrefix: tab.prefix, proxyId: p.id)
                self.tableView.reloadData()
                self.promptDisconnectActiveSockets()
            })
        }

        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Batch Multi-Tab Proxy Assignment (Matching APK showTabPicker 1:1)

    private func showBatchTabPicker() {
        if proxies.isEmpty {
            showToast("Chưa có proxy nào! Hãy qua tab 'Danh Sách Proxy' để thêm trước.")
            return
        }

        let pickProxySheet = UIAlertController(
            title: "Gán Proxy Cho Nhiều Tab",
            message: "Chọn proxy muốn gán cho hàng loạt tab:",
            preferredStyle: .actionSheet
        )

        pickProxySheet.addAction(UIAlertAction(title: "Bỏ gán proxy (Về mặc định của màn)", style: .destructive) { [weak self] _ in
            self?.presentMultiTabSelection(proxy: nil)
        })

        for p in proxies {
            pickProxySheet.addAction(UIAlertAction(title: "⚡ \(p.displayTitle) (\(p.type.uppercased()))", style: .default) { [weak self] _ in
                self?.presentMultiTabSelection(proxy: p)
            })
        }

        pickProxySheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(pickProxySheet, animated: true)
    }

    private func presentMultiTabSelection(proxy: ProxyItem?) {
        let tabs = currentMidletTabs
        let titleStr = proxy != nil ? "Gán \"\(proxy!.displayTitle)\" cho tab" : "Bỏ proxy riêng của tab"

        let vc = UIViewController()
        vc.title = titleStr
        vc.view.backgroundColor = .white

        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(tv)

        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: vc.view.topAnchor),
            tv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])

        var selectedMap: [String: Bool] = [:]
        for tab in tabs {
            let currentProxy = DecadeProxyManager.shared.proxyForTab(appId: currentAppId, slot: selectedScreenSlot, tabPrefix: tab.prefix)
            if let p = proxy {
                selectedMap[tab.prefix] = (currentProxy?.id == p.id)
            } else {
                selectedMap[tab.prefix] = (currentProxy != nil)
            }
        }

        let nav = UINavigationController(rootViewController: vc)
        let saveBtn = UIBarButtonItem(title: "Lưu", style: .done, target: nil, action: nil)
        let cancelBtn = UIBarButtonItem(title: "Hủy", style: .plain, target: nil, action: nil)
        vc.navigationItem.rightBarButtonItem = saveBtn
        vc.navigationItem.leftBarButtonItem = cancelBtn

        // Delegate / DataSource for tab multi-choice
        class MultiChoiceHelper: NSObject, UITableViewDataSource, UITableViewDelegate {
            let tabs: [MidletTab]
            var selectedMap: [String: Bool]
            init(tabs: [MidletTab], selectedMap: [String: Bool]) {
                self.tabs = tabs
                self.selectedMap = selectedMap
            }
            func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tabs.count }
            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MCell") ?? UITableViewCell(style: .default, reuseIdentifier: "MCell")
                let tab = tabs[indexPath.row]
                let isSel = selectedMap[tab.prefix] ?? false
                cell.textLabel?.text = "Tab \(tab.index) — \(tab.name)"
                cell.accessoryType = isSel ? .checkmark : .none
                return cell
            }
            func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                tableView.deselectRow(at: indexPath, animated: true)
                let tab = tabs[indexPath.row]
                let isSel = !(selectedMap[tab.prefix] ?? false)
                selectedMap[tab.prefix] = isSel
                tableView.reloadRows(at: [indexPath], with: .none)
            }
        }

        let helper = MultiChoiceHelper(tabs: tabs, selectedMap: selectedMap)
        tv.dataSource = helper
        tv.delegate = helper
        objc_setAssociatedObject(vc, "helper", helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        cancelBtn.primaryAction = UIAction { _ in nav.dismiss(animated: true) }
        saveBtn.primaryAction = UIAction { [weak self, weak nav] _ in
            guard let self = self else { return }
            let chosen = helper.selectedMap
            let selectedPrefixes = tabs.filter { chosen[$0.prefix] == true }.map { $0.prefix }

            if let p = proxy {
                DecadeProxyManager.shared.assignTabs(appId: self.currentAppId, slot: self.selectedScreenSlot, tabPrefixes: selectedPrefixes, proxyId: p.id)
            } else {
                DecadeProxyManager.shared.assignTabs(appId: self.currentAppId, slot: self.selectedScreenSlot, tabPrefixes: selectedPrefixes, proxyId: nil)
            }

            nav?.dismiss(animated: true) {
                self.tableView.reloadData()
                self.promptDisconnectActiveSockets()
            }
        }

        present(nav, animated: true)
    }

    // MARK: - Reconnect Prompt (Matching APK showDisconnectQuestion 1:1)

    private func promptDisconnectActiveSockets() {
        let alert = UIAlertController(
            title: "Áp dụng cho kết nối mới",
            message: "Socket mạng đang mở vẫn giữ đường kết nối cũ. Ngắt chúng để game tự kết nối lại qua proxy mới ngay?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ngắt ngay", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            DecadeProxyManager.shared.disconnectActiveSockets(for: self.selectedScreenSlot)
            self.showToast("Đã ngắt socket — game đang kết nối lại qua proxy mới!")
        })

        alert.addAction(UIAlertAction(title: "Để lần kết nối sau", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Delete Proxy

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if segmentedControl.selectedSegmentIndex == 0 && editingStyle == .delete {
            let item = proxies[indexPath.row]
            DecadeProxyManager.shared.deleteProxy(id: item.id)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
