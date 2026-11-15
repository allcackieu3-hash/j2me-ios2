//
//  DecadeProxyViewController.swift
//  J2MEEmulator
//
//  1:1 Replica of Decade APK "Quản lý Proxy" screen.
//  - Complete Proxy List (CRUD, SOCKS5 & HTTP)
//  - Bulk Import (ip:port:user:pass)
//  - Test Proxy Latency (ms) & Status
//  - Per-Tab Proxy Routing (Tab 1, Tab 2, Tab 3...)
//  - Instant Socket Reconnect
//

import UIKit

class DecadeProxyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let segmentedControl = UISegmentedControl(items: ["Danh Sách Proxy", "Gắn Proxy Cho Tab"])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private var proxies: [ProxyItem] {
        return DecadeProxyManager.shared.proxies
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Quản lý Proxy"
        view.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)

        setupNavBar()
        setupUI()
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TabProxyCell")
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

    // MARK: - Actions

    @objc private func addProxyTapped() {
        let alert = UIAlertController(title: "Thêm Proxy Mới", message: "Nhập thông tin máy chủ proxy:", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "IP / Tên miền (Host)" }
        alert.addTextField { tf in tf.placeholder = "Cổng (Port, vd: 1080 / 8080)"; tf.keyboardType = .numberPad }
        alert.addTextField { tf in tf.placeholder = "Tài khoản (Tùy chọn)" }
        alert.addTextField { tf in tf.placeholder = "Mật khẩu (Tùy chọn)"; tf.isSecureTextEntry = true }

        let typeAction = UIAlertAction(title: "Loại: SOCKS5", style: .default) { [weak self, weak alert] _ in
            self?.handleSaveProxy(alert: alert, type: "socks5")
        }
        let httpAction = UIAlertAction(title: "Loại: HTTP", style: .default) { [weak self, weak alert] _ in
            self?.handleSaveProxy(alert: alert, type: "http")
        }

        alert.addAction(typeAction)
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
        alert.addAction(UIAlertAction(title: "Nhập", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            let count = DecadeProxyManager.shared.importBulk(text: text)
            self?.tableView.reloadData()
            let toast = UIAlertController(title: nil, message: "Đã nhập thành công \(count) proxy!", preferredStyle: .alert)
            self?.present(toast, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast.dismiss(animated: true) }
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - TableView DataSource & Delegate

    func numberOfSections(in tableView: UITableView) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return 1
        } else {
            return 1
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return proxies.count
        } else {
            let activeSlots = activeGameViewController?.tabButtons.count ?? 1
            return max(1, activeSlots)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if segmentedControl.selectedSegmentIndex == 0 {
            return "Danh Sách Proxy Đã Lưu (\(proxies.count))"
        } else {
            return "Gắn Proxy Cho Từng Tab Đang Chạy"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segmentedControl.selectedSegmentIndex == 0 {
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "TabProxyCell", for: indexPath)
            let slot = indexPath.row
            let appName = (activeGameViewController != nil && slot < activeGameViewController!.tabSessions.count)
                ? activeGameViewController!.tabSessions[slot].appName
                : "Game MIDlet"

            let assignedProxy = DecadeProxyManager.shared.getProxy(for: slot)

            var config = cell.defaultContentConfiguration()
            config.text = "Tab \(slot + 1): \(appName)"
            config.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)

            if let p = assignedProxy {
                config.secondaryText = "⚡ Proxy: \(p.displayTitle) (\(p.type.uppercased()))"
                config.secondaryTextProperties.color = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
                config.image = UIImage(systemName: "checkmark.circle.fill")
                config.imageProperties.tintColor = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
            } else {
                config.secondaryText = "🚫 Kết nối trực tiếp (Không qua proxy)"
                config.secondaryTextProperties.color = .secondaryLabel
                config.image = UIImage(systemName: "circle")
                config.imageProperties.tintColor = .systemGray
            }

            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if segmentedControl.selectedSegmentIndex == 0 {
            // Test proxy connection latency
            let item = proxies[indexPath.row]
            showTestingIndicator(for: item)
        } else {
            // Pick proxy for this tab slot
            let slot = indexPath.row
            showProxyPickerForSlot(slot)
        }
    }

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

    private func showProxyPickerForSlot(_ slot: Int) {
        let sheet = UIAlertController(
            title: "Gắn Proxy cho Tab \(slot + 1)",
            message: "Chọn proxy cần gắn cho tab này. Game sẽ tự động kết nối qua proxy:",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "🚫 Không dùng proxy (Trực tiếp)", style: .default) { [weak self] _ in
            DecadeProxyManager.shared.assignProxy(slot: slot, proxyId: nil)
            DecadeProxyManager.shared.disconnectActiveSockets(for: slot)
            self?.tableView.reloadData()
        })

        for p in proxies {
            sheet.addAction(UIAlertAction(title: "⚡ \(p.displayTitle) (\(p.type.uppercased()))", style: .default) { [weak self] _ in
                DecadeProxyManager.shared.assignProxy(slot: slot, proxyId: p.id)
                DecadeProxyManager.shared.disconnectActiveSockets(for: slot)
                self?.tableView.reloadData()
            })
        }

        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(sheet, animated: true)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if segmentedControl.selectedSegmentIndex == 0 && editingStyle == .delete {
            let item = proxies[indexPath.row]
            DecadeProxyManager.shared.deleteProxy(id: item.id)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
