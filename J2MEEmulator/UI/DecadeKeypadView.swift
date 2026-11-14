//
//  DecadeKeypadView.swift
//  J2MEEmulator
//
//  Clean, modern on-screen virtual keypad matching the TestFlight J2ME / NSO layout:
//  - Light silver/gray theme with soft rounded pure-white buttons and deep navy glyphs
//  - 5 columns x 3 rows:
//      Col 1-2: F1, F2 / HP, MP / Tab, Size (or 0-9 Numpad toggle)
//      Col 3-5: 8-way directional pad + OK (1, 2, 3 / 4, 5, 6 / 7, 8, 9)
//

import UIKit

class DecadeKeypadView: UIView {

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var repeatTimer: Timer?
    private var repeatKeyCode: Int32 = 0
    private var isNumpadMode = false

    var onTextInputTapped: (() -> Void)?
    var onMenuTapped: (() -> Void)?

    private let mainStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeypad()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeypad()
    }

    private func setupKeypad() {
        // Light silver/gray background matching TestFlight reference
        backgroundColor = UIColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1.0)
        layer.cornerRadius = 18
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            mainStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])

        rebuildKeypad()
    }

    private func rebuildKeypad() {
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Layout definitions matching TestFlight J2ME (testflight_screen.png)
        // Col 1-2: Function keys
        // Col 3-5: Directional Pad / Numpad
        let battleLayout: [[(title: String, code: Int32, isSpecial: Bool)]] = [
            // Row 1: F1 (Soft1), F2 (Soft2), ↖ (1), ↑ (2), ↗ (3)
            [
                ("F1", -6, true),
                ("F2", -7, true),
                ("↖", 49, false),
                ("↑", 50, false),
                ("↗", 51, false)
            ],
            // Row 2: HP (Key 7), MP (Key 8), ← (4), OK (Key 5), → (6)
            [
                ("HP", 55, true),
                ("MP", 56, true),
                ("←", 52, false),
                ("OK", 53, false),
                ("→", 54, false)
            ],
            // Row 3: Tab (Key #), Size/Num (Toggle), ↙ (7), ↓ (8), ↘ (9)
            [
                ("Tab", 35, true),
                (isNumpadMode ? "Dir" : "Size", 9998, true),
                ("↙", 55, false),
                ("↓", 56, false),
                ("↘", 57, false)
            ]
        ]

        let numpadLayout: [[(title: String, code: Int32, isSpecial: Bool)]] = [
            [
                ("F1", -6, true),
                ("F2", -7, true),
                ("1", 49, false),
                ("2", 50, false),
                ("3", 51, false)
            ],
            [
                ("*", 42, true),
                ("#", 35, true),
                ("4", 52, false),
                ("5", 53, false),
                ("6", 54, false)
            ],
            [
                ("0", 48, true),
                ("Dir", 9998, true),
                ("7", 55, false),
                ("8", 56, false),
                ("9", 57, false)
            ]
        ]

        let activeLayout = isNumpadMode ? numpadLayout : battleLayout

        for row in activeLayout {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 8
            for item in row {
                let btn = UIButton(type: .system)
                btn.setTitle(item.title, for: .normal)
                btn.tag = Int(item.code)
                styleButton(btn, isSpecial: item.isSpecial, title: item.title)

                if item.code == 9998 {
                    btn.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
                } else {
                    btn.addTarget(self, action: #selector(keyDown(_:)), for: .touchDown)
                    btn.addTarget(self, action: #selector(keyUp(_:)),
                                  for: [.touchUpInside, .touchUpOutside, .touchCancel])
                }
                rowStack.addArrangedSubview(btn)
            }
            mainStack.addArrangedSubview(rowStack)
        }
    }

    private func styleButton(_ btn: UIButton, isSpecial: Bool, title: String) {
        btn.layer.cornerRadius = 14
        btn.backgroundColor = .white

        // Soft subtle shadow for elevation
        btn.layer.shadowColor = UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 0.12).cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 3
        btn.layer.shadowOpacity = 1.0

        // Border
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(white: 0.88, alpha: 0.9).cgColor

        // Text styling matching TestFlight J2ME
        let isArrow = ["↖", "↑", "↗", "←", "→", "↙", "↓", "↘"].contains(title)
        let fontSize: CGFloat = isArrow ? 24 : 18
        let fontWeight: UIFont.Weight = isArrow ? .bold : .bold

        btn.titleLabel?.font = .systemFont(ofSize: fontSize, weight: fontWeight)
        btn.setTitleColor(UIColor(red: 0.10, green: 0.18, blue: 0.36, alpha: 1.0), for: .normal)
    }

    @objc private func toggleMode() {
        haptic.impactOccurred(intensity: 0.7)
        isNumpadMode.toggle()
        rebuildKeypad()
    }

    @objc private func keyDown(_ sender: UIButton) {
        haptic.impactOccurred(intensity: 0.6)
        let code = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), code)
        sender.backgroundColor = UIColor(red: 0.82, green: 0.86, blue: 0.92, alpha: 1.0)

        repeatKeyCode = code
        repeatTimer?.invalidate()
        // Wait 0.35s before auto-repeat, then tick every 0.08s
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self, self.repeatKeyCode == code else { return }
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_REPEATED), self.repeatKeyCode)
            }
        }
    }

    @objc private func keyUp(_ sender: UIButton) {
        let code = Int32(sender.tag)
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), code)
        sender.backgroundColor = .white
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatKeyCode = 0
    }
}
