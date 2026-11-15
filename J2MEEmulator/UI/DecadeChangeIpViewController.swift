//
//  DecadeChangeIpViewController.swift
//  J2MEEmulator
//
//  1:1 Replica of Decade APK "Thay IP Phiên Bản" (Server Destination Redirection)
//  Redirects game socket connections to custom server IP/Port (e.g. private servers).
//

import UIKit

class DecadeChangeIpViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let globalSwitch = UISwitch()
    private let globalHostField = UITextField()
    private let globalPortField = UITextField()

    private let oldIpField = UITextField()
    private let newIpField = UITextField()
    private let portField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Saved rules: [(oldIp, newIp, port)]
    private var rules: [[String: String]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        title = "Thay IP Phiên Bản"

        setupNavBar()
        setupUI()
        loadSettings()
    }

    private func setupNavBar() {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 18, weight: .bold)]
        navigationController?.navigationBar.standardAppearance = navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(saveGlobalSettings))
    }

    @objc private func closeTapped() {
        saveGlobalSettings()
        dismiss(animated: true)
    }

    private func setupUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Header view with global override + rule form
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 420))

        // Card 1: Global Server Destination Override (Matching APK ChangeIpActivity)
        let globalCard = UIView()
        globalCard.backgroundColor = .white
        globalCard.layer.cornerRadius = 12
        globalCard.layer.shadowColor = UIColor.black.cgColor
        globalCard.layer.shadowOpacity = 0.05
        globalCard.layer.shadowOffset = CGSize(width: 0, height: 2)
        globalCard.layer.shadowRadius = 4
        globalCard.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(globalCard)

        let globalStack = UIStackView()
        globalStack.axis = .vertical
        globalStack.spacing = 10
        globalStack.translatesAutoresizingMaskIntoConstraints = false
        globalCard.addSubview(globalStack)

        let switchRow = UIStackView()
        switchRow.axis = .horizontal
        switchRow.alignment = .center
        switchRow.distribution = .equalSpacing

        let switchLabel = UILabel()
        switchLabel.text = "Đổi máy chủ kết nối của game"
        switchLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        switchLabel.textColor = .black
        switchRow.addArrangedSubview(switchLabel)

        globalSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        switchRow.addArrangedSubview(globalSwitch)
        globalStack.addArrangedSubview(switchRow)

        let noteLabel = UILabel()
        noteLabel.text = "Chức năng này đổi IP/cổng máy chủ đích của game (vd: vào server riêng), không phải proxy."
        noteLabel.font = .systemFont(ofSize: 12)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0
        globalStack.addArrangedSubview(noteLabel)

        globalStack.addArrangedSubview(makeInput(label: "IP/Host máy chủ mới:", field: globalHostField, placeholder: "vd: 103.179.188.45"))
        globalStack.addArrangedSubview(makeInput(label: "Cổng máy chủ mới:", field: globalPortField, placeholder: "vd: 14444", isNumber: true))

        // Card 2: Specific Redirect Rule (Old IP -> New IP)
        let ruleCard = UIView()
        ruleCard.backgroundColor = .white
        ruleCard.layer.cornerRadius = 12
        ruleCard.layer.shadowColor = UIColor.black.cgColor
        ruleCard.layer.shadowOpacity = 0.05
        ruleCard.layer.shadowOffset = CGSize(width: 0, height: 2)
        ruleCard.layer.shadowRadius = 4
        ruleCard.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(ruleCard)

        let ruleStack = UIStackView()
        ruleStack.axis = .vertical
        ruleStack.spacing = 8
        ruleStack.translatesAutoresizingMaskIntoConstraints = false
        ruleCard.addSubview(ruleStack)

        let ruleTitle = UILabel()
        ruleTitle.text = "Hoặc chuyển hướng theo từng máy chủ gốc:"
        ruleTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        ruleTitle.textColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
        ruleStack.addArrangedSubview(ruleTitle)

        ruleStack.addArrangedSubview(makeInput(label: "Máy chủ cũ (IP hoặc domain gốc):", field: oldIpField, placeholder: "27.0.14.73 hoặc nso1.teamobi.com"))
        ruleStack.addArrangedSubview(makeInput(label: "Máy chủ mới (Đích thay thế):", field: newIpField, placeholder: "103.179.188.45"))
        ruleStack.addArrangedSubview(makeInput(label: "Cổng đích:", field: portField, placeholder: "14444", isNumber: true))

        let addRuleBtn = UIButton(type: .system)
        addRuleBtn.setTitle("➕ Thêm quy tắc chuyển hướng", style: .default)
        addRuleBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        addRuleBtn.addTarget(self, action: #selector(addRuleTapped), for: .touchUpInside)
        ruleStack.addArrangedSubview(addRuleBtn)

        NSLayoutConstraint.activate([
            globalCard.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            globalCard.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            globalCard.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            globalStack.topAnchor.constraint(equalTo: globalCard.topAnchor, constant: 12),
            globalStack.leadingAnchor.constraint(equalTo: globalCard.leadingAnchor, constant: 12),
            globalStack.trailingAnchor.constraint(equalTo: globalCard.trailingAnchor, constant: -12),
            globalStack.bottomAnchor.constraint(equalTo: globalCard.bottomAnchor, constant: -12),

            ruleCard.topAnchor.constraint(equalTo: globalCard.bottomAnchor, constant: 12),
            ruleCard.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            ruleCard.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            ruleCard.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10),

            ruleStack.topAnchor.constraint(equalTo: ruleCard.topAnchor, constant: 12),
            ruleStack.leadingAnchor.constraint(equalTo: ruleCard.leadingAnchor, constant: 12),
            ruleStack.trailingAnchor.constraint(equalTo: ruleCard.trailingAnchor, constant: -12),
            ruleStack.bottomAnchor.constraint(equalTo: ruleCard.bottomAnchor, constant: -12),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.tableHeaderView = headerView
    }

    private func makeInput(label: String, field: UITextField, placeholder: String, isNumber: Bool = false) -> UIView {
        let v = UIStackView()
        v.axis = .vertical
        v.spacing = 2

        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .systemGray
        v.addArrangedSubview(l)

        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        field.textColor = .black
        if isNumber { field.keyboardType = .numberPad }
        v.addArrangedSubview(field)

        return v
    }

    private func loadSettings() {
        let ud = UserDefaults.standard
        globalSwitch.isOn = ud.bool(forKey: "decade_server_enabled")
        globalHostField.text = ud.string(forKey: "decade_server_host") ?? ""
        let port = ud.integer(forKey: "decade_server_port")
        globalPortField.text = port > 0 ? "\(port)" : ""

        if let saved = ud.array(forKey: "decade_ip_rules") as? [[String: String]] {
            rules = saved
        } else {
            rules = []
        }
        tableView.reloadData()
        DecadeChangeIpViewController.syncToNative()
    }

    @objc private func switchChanged() {
        saveGlobalSettings()
    }

    @objc private func saveGlobalSettings() {
        let ud = UserDefaults.standard
        ud.set(globalSwitch.isOn, forKey: "decade_server_enabled")
        ud.set(globalHostField.text?.trimmingCharacters(in: .whitespaces) ?? "", forKey: "decade_server_host")
        let port = Int(globalPortField.text?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        ud.set(port, forKey: "decade_server_port")

        DecadeChangeIpViewController.syncToNative()
    }

    @objc private func addRuleTapped() {
        guard let oldIp = oldIpField.text?.trimmingCharacters(in: .whitespaces), !oldIp.isEmpty,
              let newIp = newIpField.text?.trimmingCharacters(in: .whitespaces), !newIp.isEmpty else {
            let alert = UIAlertController(title: "Lỗi", message: "Vui lòng nhập cả máy chủ cũ và máy chủ đích", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let port = portField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let newRule = ["old": oldIp, "new": newIp, "port": port]
        rules.insert(newRule, at: 0)

        UserDefaults.standard.set(rules, forKey: "decade_ip_rules")
        DecadeChangeIpViewController.syncToNative()

        oldIpField.text = ""
        newIpField.text = ""
        portField.text = ""
        view.endEditing(true)
        tableView.reloadData()
    }

    // MARK: - Native Bridge Sync

    static func syncToNative() {
        let ud = UserDefaults.standard
        let enabled = ud.bool(forKey: "decade_server_enabled")
        let host = ud.string(forKey: "decade_server_host") ?? ""
        let port = ud.integer(forKey: "decade_server_port")

        host.withCString { hPtr in
            jvm_bridge_set_server_override(enabled ? 1 : 0, hPtr, Int32(port))
        }

        jvm_bridge_clear_server_redirect_rules()

        if let rules = ud.array(forKey: "decade_ip_rules") as? [[String: String]] {
            for r in rules {
                guard let old = r["old"], let new = r["new"] else { continue }
                let rPort = Int32(r["port"] ?? "") ?? 0
                old.withCString { oldPtr in
                    new.withCString { newPtr in
                        jvm_bridge_add_server_redirect_rule(oldPtr, newPtr, rPort)
                    }
                }
            }
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Quy tắc chuyển hướng cụ thể (\(rules.count))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rules.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RuleCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "RuleCell")

        let rule = rules[indexPath.row]
        let old = rule["old"] ?? ""
        let new = rule["new"] ?? ""
        let port = rule["port"] ?? ""

        cell.textLabel?.text = "\(old) ➔ \(new)"
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cell.textLabel?.textColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)

        cell.detailTextLabel?.text = port.isEmpty ? "Chuyển tiếp tất cả các cổng" : "Cổng đích: \(port)"
        cell.detailTextLabel?.textColor = .systemGray

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            rules.remove(at: indexPath.row)
            UserDefaults.standard.set(rules, forKey: "decade_ip_rules")
            DecadeChangeIpViewController.syncToNative()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}
