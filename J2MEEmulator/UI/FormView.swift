//
//  FormView.swift
//  J2MEEmulator
//
//  Displays J2ME Forms/Lists/TextBoxes using authentic KamenRider Decade native widgets.
//  Matches Android KamenRider Decade 1:1.
//

import UIKit

// ============================================================
// MARK: - J2METextBoxView (Authentic Decade Full-screen In-Game Text Input)
// ============================================================

class J2METextBoxView: UIView, UITextViewDelegate {

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let bottomButtonBar = UIStackView()
    private var commandButtons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .white

        // White editing canvas
        textView.font = .systemFont(ofSize: 18)
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.delegate = self
        textView.returnKeyType = .done
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        // Placeholder
        placeholderLabel.text = "Chạm vào đây để nhập nội dung..."
        placeholderLabel.font = .systemFont(ofSize: 18)
        placeholderLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        // Setup Keyboard Accessory Toolbar with the requested "nút V" (✓ Done)
        setupKeyboardToolbar()

        // Tap on background dismisses keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)

        // Bottom Soft Button Bar matching Android Decade
        bottomButtonBar.axis = .horizontal
        bottomButtonBar.spacing = 8
        bottomButtonBar.distribution = .fillEqually
        bottomButtonBar.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        bottomButtonBar.layoutMargins = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        bottomButtonBar.isLayoutMarginsRelativeArrangement = true
        bottomButtonBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomButtonBar)

        // Top border for bottom bar
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textView.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -4),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 5),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomButtonBar.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            bottomButtonBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomButtonBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomButtonBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            bottomButtonBar.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    /// Setup the keyboard accessory toolbar with the "V" (✓) close button
    private func setupKeyboardToolbar() {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barTintColor = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)

        // Clear / Xóa text button on left
        let clearBtn = UIBarButtonItem(title: "Xóa", style: .plain, target: self, action: #selector(clearText))
        clearBtn.tintColor = .systemGray

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // The requested "nút V" / Done checkmark button:
        // Displays "✓" (V) or "Xong" in prominent royal blue
        let doneBtn = UIBarButtonItem(title: "✓ Xong", style: .done, target: self, action: #selector(dismissKeyboard))
        doneBtn.tintColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
        doneBtn.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ], for: .normal)

        toolbar.items = [clearBtn, flexSpace, doneBtn]
        textView.inputAccessoryView = toolbar
    }

    @objc private func clearText() {
        textView.text = ""
        placeholderLabel.isHidden = false
        syncTextToNative()
    }

    /// User requested: "nút V ấn vào thì nó đóng bàn phím sau khi nhập xong"
    @objc func dismissKeyboard() {
        textView.resignFirstResponder()
        syncTextToNative()
    }

    @objc private func backgroundTapped() {
        textView.resignFirstResponder()
        syncTextToNative()
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        syncTextToNative()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // If user presses return/enter on the single line, close keyboard
        if text == "\n" {
            dismissKeyboard()
            return false
        }
        return true
    }

    private func syncTextToNative() {
        let text = textView.text ?? ""
        text.withCString { cstr in
            j2me_ui_set_textbox_text(cstr)
        }
    }

    func buildFromNativeData() {
        // Load initial text
        let initial = String(cString: j2me_ui_get_textbox_text())
        textView.text = initial
        placeholderLabel.isHidden = !initial.isEmpty

        // Build command buttons (CANCEL, OK, MENU)
        bottomButtonBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commandButtons.removeAll()

        let cmdCount = j2me_ui_get_command_count()
        for i in 0..<cmdCount {
            let cmdLabel = String(cString: j2me_ui_get_command_label(Int32(i)))
            let cmdId = j2me_ui_get_command_id(Int32(i))

            let btn = UIButton(type: .system)
            btn.setTitle(cmdLabel.uppercased(), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            btn.tag = Int(cmdId)

            let isOk = cmdLabel.lowercased().contains("ok") || cmdLabel.lowercased().contains("chọn") || cmdLabel.lowercased().contains("select")
            let isCancel = cmdLabel.lowercased().contains("cancel") || cmdLabel.lowercased().contains("hủy") || cmdLabel.lowercased().contains("thoát")

            if isOk {
                btn.backgroundColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
                btn.setTitleColor(.white, for: .normal)
            } else if isCancel {
                btn.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
                btn.setTitleColor(.darkGray, for: .normal)
            } else {
                btn.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
                btn.setTitleColor(.darkGray, for: .normal)
            }

            btn.layer.cornerRadius = 6
            btn.addTarget(self, action: #selector(commandTapped(_:)), for: .touchUpInside)

            bottomButtonBar.addArrangedSubview(btn)
            commandButtons.append(btn)
        }

        // Auto focus textview if requested
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.textView.becomeFirstResponder()
        }
    }

    @objc private func commandTapped(_ sender: UIButton) {
        dismissKeyboard()
        syncTextToNative()
        let cmdId = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), cmdId)
    }
}

// ============================================================
// MARK: - FormView (Multi-item forms)
// ============================================================

class FormView: UIView {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var commandButtons: [UIButton] = []
    private let commandBar = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .white

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        commandBar.axis = .horizontal
        commandBar.spacing = 10
        commandBar.distribution = .fillEqually
        commandBar.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        commandBar.layoutMargins = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        commandBar.isLayoutMarginsRelativeArrangement = true
        commandBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(commandBar)

        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: commandBar.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            commandBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            commandBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            commandBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            commandBar.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    func buildFromNativeData() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commandBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commandButtons.removeAll()

        let count = j2me_ui_get_form_item_count()
        for i in 0..<count {
            let itemType = j2me_ui_get_form_item_type(Int32(i))
            let label = String(cString: j2me_ui_get_form_item_label(Int32(i)))
            let text = String(cString: j2me_ui_get_form_item_text(Int32(i)))

            switch itemType {
            case 0:
                addStringItem(label: label, text: text)
            case 1:
                addTextField(label: label, text: text)
            default:
                addStringItem(label: label, text: text)
            }
        }

        let cmdCount = j2me_ui_get_command_count()
        for i in 0..<cmdCount {
            let cmdLabel = String(cString: j2me_ui_get_command_label(Int32(i)))
            let cmdId = j2me_ui_get_command_id(Int32(i))

            let btn = UIButton(type: .system)
            btn.setTitle(cmdLabel, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            btn.tag = Int(cmdId)
            btn.backgroundColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 6
            btn.addTarget(self, action: #selector(commandTapped(_:)), for: .touchUpInside)
            commandBar.addArrangedSubview(btn)
            commandButtons.append(btn)
        }
    }

    private func addStringItem(label: String, text: String) {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 3

        if !label.isEmpty {
            let labelView = UILabel()
            labelView.text = label
            labelView.font = .boldSystemFont(ofSize: 14)
            labelView.textColor = .secondaryLabel
            container.addArrangedSubview(labelView)
        }

        if !text.isEmpty {
            let textView = UILabel()
            textView.text = text
            textView.font = .systemFont(ofSize: 16)
            textView.textColor = .black
            textView.numberOfLines = 0
            container.addArrangedSubview(textView)
        }

        stackView.addArrangedSubview(container)
    }

    private func addTextField(label: String, text: String) {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        if !label.isEmpty {
            let labelView = UILabel()
            labelView.text = label
            labelView.font = .boldSystemFont(ofSize: 14)
            labelView.textColor = .secondaryLabel
            container.addArrangedSubview(labelView)
        }

        let tf = UITextField()
        tf.text = text
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = .black
        tf.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        tf.returnKeyType = .done
        tf.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
        container.addArrangedSubview(tf)

        stackView.addArrangedSubview(container)
    }

    @objc private func commandTapped(_ sender: UIButton) {
        endEditing(true)
        let cmdId = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), cmdId)
    }

    @objc private func textFieldChanged(_ sender: UITextField) {
        let text = sender.text ?? ""
        text.withCString { cstr in
            j2me_ui_set_textbox_text(cstr)
        }
    }
}

// ============================================================
// MARK: - J2MEListView (AngelChip Menu matching Screenshot 2 & 3)
// ============================================================

class J2MEListView: UIView, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var items: [String] = []
    private var selectedRow: Int = 0
    private let bottomButtonBar = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .white

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.separatorColor = UIColor(white: 0.88, alpha: 1.0)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        // Bottom Softkeys: Red MENU and Red THOÁT matching Screenshot 2 & 3
        bottomButtonBar.axis = .horizontal
        bottomButtonBar.distribution = .equalSpacing
        bottomButtonBar.alignment = .center
        bottomButtonBar.backgroundColor = .white
        bottomButtonBar.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        bottomButtonBar.isLayoutMarginsRelativeArrangement = true
        bottomButtonBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomButtonBar)

        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0.88, alpha: 1.0)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomButtonBar.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            bottomButtonBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomButtonBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomButtonBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            bottomButtonBar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    func buildFromNativeData() {
        items.removeAll()
        let count = j2me_ui_get_list_item_count()
        for i in 0..<count {
            items.append(String(cString: j2me_ui_get_list_item(Int32(i))))
        }
        selectedRow = 0
        tableView.reloadData()

        // Rebuild bottom red buttons (MENU / THOÁT)
        bottomButtonBar.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let cmdCount = j2me_ui_get_command_count()
        if cmdCount == 0 {
            // Default Menu / Thoát buttons
            let leftBtn = makeRedButton(title: "MENU", tag: 0)
            let rightBtn = makeRedButton(title: "THOÁT", tag: 1)
            bottomButtonBar.addArrangedSubview(leftBtn)
            bottomButtonBar.addArrangedSubview(rightBtn)
        } else {
            for i in 0..<cmdCount {
                let cmdLabel = String(cString: j2me_ui_get_command_label(Int32(i)))
                let cmdId = j2me_ui_get_command_id(Int32(i))
                let btn = makeRedButton(title: cmdLabel.uppercased(), tag: Int(cmdId))
                bottomButtonBar.addArrangedSubview(btn)
            }
        }
    }

    private func makeRedButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.setTitleColor(UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1.0), for: .normal) // Red #E53935
        btn.tag = tag
        btn.addTarget(self, action: #selector(commandTapped(_:)), for: .touchUpInside)
        return btn
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DecadeListCell") ??
                   UITableViewCell(style: .default, reuseIdentifier: "DecadeListCell")

        let isSelected = indexPath.row == selectedRow
        cell.backgroundColor = isSelected ? UIColor(red: 0.80, green: 0.84, blue: 0.98, alpha: 1.0) : .white

        var config = cell.defaultContentConfiguration()
        config.text = items[indexPath.row]
        config.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
        config.textProperties.color = .black

        // Check if item has active green play icon (like Screenshot 3)
        if items[indexPath.row].hasPrefix("▶") || items[indexPath.row].contains("play") {
            config.image = UIImage(systemName: "play.fill")
            config.imageProperties.tintColor = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
        } else {
            config.image = nil
        }

        cell.contentConfiguration = config
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        tableView.reloadData()
        j2me_input_post_key(Int32(J2ME_UI_LIST_SELECT), Int32(indexPath.row))
    }

    @objc private func commandTapped(_ sender: UIButton) {
        j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), Int32(sender.tag))
    }
}
