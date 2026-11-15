//
//  DecadeChangeIpViewController.swift
//  J2MEEmulator
//
//  Authentic Decade "Thay IP Phiên Bản" screen (IP redirection).
//

import UIKit

class DecadeChangeIpViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

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
        loadRules()
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Thêm", style: .done, target: self, action: #selector(addRuleTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func setupUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Header view with input form
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 260))
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let descLabel = UILabel()
        descLabel.text = "Chuyển hướng kết nối mạng J2ME sang địa chỉ IP máy chủ mới (vd: server private):"
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        stack.addArrangedSubview(descLabel)

        stack.addArrangedSubview(makeInput(label: "IP/Host nguồn (Cũ):", field: oldIpField, placeholder: "123.30.238.16 hoặc nso1.teamobi.com"))
        stack.addArrangedSubview(makeInput(label: "IP/Host đích (Mới):", field: newIpField, placeholder: "103.179.188.45"))
        stack.addArrangedSubview(makeInput(label: "Cổng kết nối:", field: portField, placeholder: "14444 (Tùy chọn)", isNumber: true))

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 14),
            card.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),

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

    private func loadRules() {
        if let saved = UserDefaults.standard.array(forKey: "decade_ip_rules") as? [[String: String]] {
            rules = saved
        } else {
            // Sample default for Ninja School
            rules = [
                ["old": "123.30.238.16", "new": "103.179.188.45", "port": "14444"]
            ]
        }
        tableView.reloadData()
    }

    private func saveRules() {
        UserDefaults.standard.set(rules, forKey: "decade_ip_rules")
    }

    @objc private func addRuleTapped() {
        guard let oldIp = oldIpField.text?.trimmingCharacters(in: .whitespaces), !oldIp.isEmpty,
              let newIp = newIpField.text?.trimmingCharacters(in: .whitespaces), !newIp.isEmpty else {
            let alert = UIAlertController(title: "Lỗi", message: "Vui lòng nhập cả IP nguồn và IP đích", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let port = portField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let newRule = ["old": oldIp, "new": newIp, "port": port]
        rules.insert(newRule, at: 0)
        saveRules()

        oldIpField.text = ""
        newIpField.text = ""
        portField.text = ""
        view.endEditing(true)
        tableView.reloadData()
    }

    // ============================================================
    // MARK: - TableView DataSource & Delegate
    // ============================================================

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Danh sách chuyển hướng IP đang áp dụng (\(rules.count))"
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

        cell.accessoryType = .none
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            rules.remove(at: indexPath.row)
            saveRules()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}
