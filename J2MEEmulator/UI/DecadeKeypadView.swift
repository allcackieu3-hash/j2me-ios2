//
//  DecadeKeypadView.swift
//  J2MEEmulator
//
//  Authentic KamenRider Decade on-screen keypad layout for Portrait mode.
//  Includes 8-way directional navigation, full numpad (0-9, *, #), soft keys (L, R),
//  backspace, Decade multi-tab switcher, and rapid text input trigger.
//

import UIKit

class DecadeKeypadView: UIView {

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var repeatTimer: Timer?
    private var repeatKeyCode: Int32 = 0

    var onTextInputTapped: (() -> Void)?
    var onMenuTapped: (() -> Void)?
    var onTabTapped: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeypad()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeypad()
    }

    private func setupKeypad() {
        backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 0.98)
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        // Top accent line in Decade Magenta
        let topLine = UIView()
        topLine.backgroundColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 0.8)
        topLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topLine)

        // Grid Definition: 5 columns x 4 rows
        // J2ME Keycodes:
        // L = -6 (SoftLeft), R = -7 (SoftRight)
        // Directional: 1 ↖ (49), 2 ↑ (50), 3 ↗ (51), 4 ← (52), 5 F (53), 6 → (54), 7 ↙ (55), 8 ↓ (56), 9 ↘ (57)
        // Extra Numpad: * (42), 0 (48), # (35)
        // Actions: Backspace (-8 / 8), Text Input (9999), Tabs (10001, 10002, 10003), Menu (10004)
        let layout: [[(title: String, code: Int32, type: KeyType)]] = [
            // Row 1: Soft Left, 1 ↖, 2 ↑, 3 ↗, Soft Right
            [
                ("L", -6, .softKey),
                ("1 ↖", 49, .diagonal),
                ("2 ↑", 50, .direction),
                ("3 ↗", 51, .diagonal),
                ("R", -7, .softKey)
            ],
            // Row 2: *, 4 ←, 5 ★ F, 6 →, #
            [
                ("*", 42, .number),
                ("4 ←", 52, .direction),
                ("5 ★ F", 53, .fire),
                ("6 →", 54, .direction),
                ("#", 35, .number)
            ],
            // Row 3: 0, 7 ↙, 8 ↓, 9 ↘, ⌫ Xóa
            [
                ("0", 48, .number),
                ("7 ↙", 55, .diagonal),
                ("8 ↓", 56, .direction),
                ("9 ↘", 57, .diagonal),
                ("⌫", -8, .backspace)
            ],
            // Row 4: Action Row: [⌨ Nhập], [Tab 1], [Tab 2], [+ Tab], [⚙ Menu]
            [
                ("⌨ Nhập", 9999, .textInput),
                ("Tab 1", 10001, .tabSwitch),
                ("Tab 2", 10002, .tabSwitch),
                ("+ Tab", 10003, .tabAdd),
                ("⚙ Menu", 10004, .menu)
            ]
        ]

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 5
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: topAnchor),
            topLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1.5),

            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            mainStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
        ])

        for row in layout {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 5
            for item in row {
                let btn = UIButton(type: .system)
                btn.setTitle(item.title, for: .normal)
                btn.tag = Int(item.code)
                styleButton(btn, type: item.type)

                switch item.type {
                case .textInput:
                    btn.addTarget(self, action: #selector(textInputTapped), for: .touchUpInside)
                case .tabSwitch:
                    btn.addTarget(self, action: #selector(tabSwitchTapped(_:)), for: .touchUpInside)
                case .tabAdd:
                    btn.addTarget(self, action: #selector(tabAddTapped), for: .touchUpInside)
                case .menu:
                    btn.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
                default:
                    btn.addTarget(self, action: #selector(keyDown(_:)), for: .touchDown)
                    btn.addTarget(self, action: #selector(keyUp(_:)),
                                  for: [.touchUpInside, .touchUpOutside, .touchCancel])
                }
                rowStack.addArrangedSubview(btn)
            }
            mainStack.addArrangedSubview(rowStack)
        }
    }

    enum KeyType {
        case softKey
        case direction
        case diagonal
        case fire
        case number
        case textInput
        case backspace
        case tabSwitch
        case tabAdd
        case menu
    }

    private func styleButton(_ btn: UIButton, type: KeyType) {
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 1

        switch type {
        case .fire:
            // KamenRider Decade Magenta
            btn.backgroundColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .heavy)
            btn.layer.borderColor = UIColor(red: 1.0, green: 0.35, blue: 0.55, alpha: 0.7).cgColor

        case .softKey:
            // Softkeys L & R with Cyan accents
            btn.backgroundColor = UIColor(red: 0.11, green: 0.17, blue: 0.25, alpha: 1.0)
            btn.setTitleColor(UIColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
            btn.layer.borderColor = UIColor(red: 0.25, green: 0.40, blue: 0.60, alpha: 0.5).cgColor

        case .direction:
            // Cardinal directions: 2, 4, 6, 8
            btn.backgroundColor = UIColor(red: 0.15, green: 0.19, blue: 0.27, alpha: 1.0)
            btn.setTitleColor(UIColor(white: 0.98, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
            btn.layer.borderColor = UIColor(red: 0.28, green: 0.36, blue: 0.50, alpha: 0.4).cgColor

        case .diagonal:
            // Diagonals: 1, 3, 7, 9
            btn.backgroundColor = UIColor(white: 0.13, alpha: 1.0)
            btn.setTitleColor(UIColor(white: 0.88, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            btn.layer.borderColor = UIColor(white: 0.25, alpha: 0.4).cgColor

        case .number:
            // *, 0, #
            btn.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
            btn.setTitleColor(UIColor(white: 0.85, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            btn.layer.borderColor = UIColor(white: 0.22, alpha: 0.4).cgColor

        case .textInput:
            // Emerald / Teal for rapid keyboard trigger
            btn.backgroundColor = UIColor(red: 0.05, green: 0.50, blue: 0.45, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
            btn.layer.borderColor = UIColor(red: 0.10, green: 0.70, blue: 0.60, alpha: 0.6).cgColor

        case .backspace:
            // Red accent for Delete
            btn.backgroundColor = UIColor(red: 0.58, green: 0.14, blue: 0.14, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            btn.layer.borderColor = UIColor(red: 0.80, green: 0.22, blue: 0.22, alpha: 0.6).cgColor

        case .tabSwitch:
            btn.backgroundColor = UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1.0)
            btn.setTitleColor(UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
            btn.layer.borderColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 0.4).cgColor

        case .tabAdd:
            btn.backgroundColor = UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1.0)
            btn.setTitleColor(UIColor(white: 0.8, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
            btn.layer.borderColor = UIColor(white: 0.3, alpha: 0.4).cgColor

        case .menu:
            btn.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
            btn.setTitleColor(UIColor(white: 0.9, alpha: 1.0), for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            btn.layer.borderColor = UIColor(white: 0.3, alpha: 0.4).cgColor
        }
    }

    @objc private func textInputTapped() {
        haptic.impactOccurred(intensity: 0.8)
        onTextInputTapped?()
    }

    @objc private func tabSwitchTapped(_ sender: UIButton) {
        haptic.impactOccurred(intensity: 0.5)
        let slot = sender.tag == 10001 ? 1 : 2
        onTabTapped?(slot)
    }

    @objc private func tabAddTapped() {
        haptic.impactOccurred(intensity: 0.5)
        onTabTapped?(0) // Add new tab
    }

    @objc private func menuTapped() {
        haptic.impactOccurred(intensity: 0.6)
        onMenuTapped?()
    }

    @objc private func keyDown(_ sender: UIButton) {
        haptic.impactOccurred(intensity: 0.6)
        let code = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), code)
        sender.alpha = 0.65

        // Also post ASCII backspace if code is -8
        if code == -8 {
            j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), 8)
        }

        repeatKeyCode = code
        repeatTimer?.invalidate()
        // Delay 0.35s before auto-repeat, then tick every 0.08s
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self, self.repeatKeyCode == code else { return }
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_REPEATED), self.repeatKeyCode)
                if self.repeatKeyCode == -8 {
                    j2me_input_post_key(Int32(J2ME_INPUT_KEY_REPEATED), 8)
                }
            }
        }
    }

    @objc private func keyUp(_ sender: UIButton) {
        let code = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), code)
        if code == -8 {
            j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), 8)
        }
        sender.alpha = 1.0
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatKeyCode = 0
    }
}
