//
//  DecadeProxyViewController.swift
//  J2MEEmulator
//
//  Authentic Decade "Quản lý Proxy" screen.
//

import UIKit

class DecadeProxyViewController: UIViewController {

    private let proxySwitch = UISwitch()
    private let typeSegment = UISegmentedControl(items: ["HTTP", "SOCKS5"])
    private let hostField = UITextField()
    private let portField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        title = "Quản lý Proxy"

        setupNavBar()
        setupUI()
        loadSavedProxy()
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(saveTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // 1. Enable Switch Card
        let switchCard = makeCard()
        let switchStack = UIStackView()
        switchStack.axis = .horizontal
        switchStack.alignment = .center
        switchStack.distribution = .equalSpacing

        let switchLabel = UILabel()
        switchLabel.text = "Sử dụng Proxy cho game"
        switchLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        switchLabel.textColor = .black
        switchStack.addArrangedSubview(switchLabel)
        switchStack.addArrangedSubview(proxySwitch)
        switchCard.addSubview(switchStack)
        switchStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            switchStack.topAnchor.constraint(equalTo: switchCard.topAnchor, constant: 14),
            switchStack.leadingAnchor.constraint(equalTo: switchCard.leadingAnchor, constant: 16),
            switchStack.trailingAnchor.constraint(equalTo: switchCard.trailingAnchor, constant: -16),
            switchStack.bottomAnchor.constraint(equalTo: switchCard.bottomAnchor, constant: -14),
        ])
        stack.addArrangedSubview(switchCard)

        // 2. Details Card
        let detailsCard = makeCard()
        let detailsStack = UIStackView()
        detailsStack.axis = .vertical
        detailsStack.spacing = 12

        let typeLabel = UILabel()
        typeLabel.text = "Loại Proxy"
        typeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        typeLabel.textColor = .systemGray
        detailsStack.addArrangedSubview(typeLabel)
        typeSegment.selectedSegmentIndex = 0
        detailsStack.addArrangedSubview(typeSegment)

        detailsStack.addArrangedSubview(makeFieldGroup(label: "Máy chủ (IP / Host):", field: hostField, placeholder: "103.142.109.2 hoặc domain"))
        detailsStack.addArrangedSubview(makeFieldGroup(label: "Cổng (Port):", field: portField, placeholder: "8080 hoặc 1080", isNumber: true))
        detailsStack.addArrangedSubview(makeFieldGroup(label: "Tài khoản (Tùy chọn):", field: userField, placeholder: "Để trống nếu không yêu cầu"))
        detailsStack.addArrangedSubview(makeFieldGroup(label: "Mật khẩu (Tùy chọn):", field: passField, placeholder: "Để trống nếu không yêu cầu", isSecure: true))

        detailsCard.addSubview(detailsStack)
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detailsStack.topAnchor.constraint(equalTo: detailsCard.topAnchor, constant: 16),
            detailsStack.leadingAnchor.constraint(equalTo: detailsCard.leadingAnchor, constant: 16),
            detailsStack.trailingAnchor.constraint(equalTo: detailsCard.trailingAnchor, constant: -16),
            detailsStack.bottomAnchor.constraint(equalTo: detailsCard.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(detailsCard)

        // 3. Status label & Save Button
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        stack.addArrangedSubview(statusLabel)

        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("Lưu và kích hoạt", for: .normal)
        saveBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        saveBtn.backgroundColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 10
        saveBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        stack.addArrangedSubview(saveBtn)
    }

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 12
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.05
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
        return v
    }

    private func makeFieldGroup(label: String, field: UITextField, placeholder: String, isNumber: Bool = false, isSecure: Bool = false) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .systemGray
        container.addArrangedSubview(l)

        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        field.textColor = .black
        if isNumber { field.keyboardType = .numberPad }
        if isSecure { field.isSecureTextEntry = true }
        container.addArrangedSubview(field)

        return container
    }

    private func loadSavedProxy() {
        let ud = UserDefaults.standard
        proxySwitch.isOn = ud.bool(forKey: "decade_proxy_enabled")
        typeSegment.selectedSegmentIndex = ud.integer(forKey: "decade_proxy_type")
        hostField.text = ud.string(forKey: "decade_proxy_host") ?? ""
        let port = ud.integer(forKey: "decade_proxy_port")
        portField.text = port > 0 ? String(port) : ""
        userField.text = ud.string(forKey: "decade_proxy_user") ?? ""
        passField.text = ud.string(forKey: "decade_proxy_pass") ?? ""

        updateStatus()
    }

    private func updateStatus() {
        if proxySwitch.isOn, let host = hostField.text, !host.isEmpty {
            let typeName = typeSegment.selectedSegmentIndex == 0 ? "HTTP" : "SOCKS5"
            statusLabel.text = "✓ Proxy đang hoạt động: \(typeName)://\(host):\(portField.text ?? "")"
            statusLabel.textColor = UIColor(red: 0.18, green: 0.65, blue: 0.35, alpha: 1.0)
        } else {
            statusLabel.text = "Proxy chưa kích hoạt (kết nối trực tiếp)"
            statusLabel.textColor = .systemGray
        }
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        let ud = UserDefaults.standard
        ud.set(proxySwitch.isOn, forKey: "decade_proxy_enabled")
        ud.set(typeSegment.selectedSegmentIndex, forKey: "decade_proxy_type")
        ud.set(hostField.text?.trimmingCharacters(in: .whitespaces) ?? "", forKey: "decade_proxy_host")
        ud.set(Int(portField.text ?? "") ?? 0, forKey: "decade_proxy_port")
        ud.set(userField.text ?? "", forKey: "decade_proxy_user")
        ud.set(passField.text ?? "", forKey: "decade_proxy_pass")

        updateStatus()

        let alert = UIAlertController(title: "Thành công", message: "Đã lưu cài đặt Proxy!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
