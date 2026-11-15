//
//  DecadeKeypadView.swift
//  J2MEEmulator
//
//  Authentic KamenRider Decade virtual keypad with full customization:
//  - Pure directional keycodes (Canvas.UP=-1, DOWN=-2, LEFT=-3, RIGHT=-4, FIRE=-5, etc.)
//    -> NEVER outputs numbers when navigating!
//  - "Công tắc cấu trúc phím" (Layout switcher): Arrows, Numpad, Combined
//  - "Ẩn các phím" (Key visibility toggle for diagonals, softkeys, fire)
//  - Size & opacity customization
//

import UIKit

enum DecadeKeypadLayout: Int {
    case arrows = 0    // Decade 5x3 Directional Pad (Default)
    case numpad = 1    // Phone Numpad (0-9, *, #)
    case combined = 2  // Arrows + Numpad combined
}

class DecadeKeypadView: UIView {

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var repeatTimer: Timer?
    private var activeCode1: Int32 = 0
    private var activeCode2: Int32 = 0

    var onTextInputTapped: (() -> Void)?
    var onMenuTapped: (() -> Void)?

    private let mainStack = UIStackView()

    // Customization state
    var currentLayout: DecadeKeypadLayout = .arrows {
        didSet { rebuildKeypad() }
    }
    var showDiagonalKeys: Bool = true {
        didSet { rebuildKeypad() }
    }
    var showSoftKeys: Bool = true {
        didSet { rebuildKeypad() }
    }
    var showFireKey: Bool = true {
        didSet { rebuildKeypad() }
    }
    var keypadAlphaValue: CGFloat = 0.70 {
        didSet { rebuildKeypad() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeypad()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeypad()
    }

    private func setupKeypad() {
        backgroundColor = UIColor(red: 0.925, green: 0.937, blue: 0.953, alpha: 1.0)
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])

        rebuildKeypad()
    }

    func rebuildKeypad() {
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch currentLayout {
        case .arrows:
            buildArrowsLayout()
        case .numpad:
            buildNumpadLayout()
        case .combined:
            buildCombinedLayout()
        }
    }

    // ============================================================
    // MARK: - Layout 1: Decade Mũi tên (Arrows - Pure Navigation, NO NUMBERS)
    // ============================================================

    private func buildArrowsLayout() {
        // Pure navigation keycodes (negative J2ME values, never characters/numbers):
        // Canvas.UP = -1, DOWN = -2, LEFT = -3, RIGHT = -4, FIRE = -5, SOFT1 = -6, SOFT2 = -7
        // Diagonals send dual navigation codes (e.g. -1 and -3 for UP+LEFT)

        let upLeftCodes: (Int32, Int32) = showDiagonalKeys ? (-1, -3) : (0, 0)
        let upRightCodes: (Int32, Int32) = showDiagonalKeys ? (-1, -4) : (0, 0)
        let downLeftCodes: (Int32, Int32) = showDiagonalKeys ? (-2, -3) : (0, 0)
        let downRightCodes: (Int32, Int32) = showDiagonalKeys ? (-2, -4) : (0, 0)

        let soft1Code: Int32 = showSoftKeys ? -6 : 0
        let soft2Code: Int32 = showSoftKeys ? -7 : 0
        let fireCode: Int32 = showFireKey ? -5 : 0

        let layout: [[(title: String, c1: Int32, c2: Int32, isEmpty: Bool)]] = [
            // Row 1: [ L ]  [ ↖ ]  [ ↑ ]  [ ↗ ]  [ R ]
            [
                (showSoftKeys ? "L" : "", soft1Code, 0, !showSoftKeys),
                (showDiagonalKeys ? "↖" : "", upLeftCodes.0, upLeftCodes.1, !showDiagonalKeys),
                ("↑", -1, 0, false),
                (showDiagonalKeys ? "↗" : "", upRightCodes.0, upRightCodes.1, !showDiagonalKeys),
                (showSoftKeys ? "R" : "", soft2Code, 0, !showSoftKeys)
            ],
            // Row 2: (empty) [ ← ]  [ F ]  [ → ] (empty)
            [
                ("", 0, 0, true),
                ("←", -3, 0, false),
                (showFireKey ? "F" : "", fireCode, 0, !showFireKey),
                ("→", -4, 0, false),
                ("", 0, 0, true)
            ],
            // Row 3: (empty) [ ↙ ]  [ ↓ ]  [ ↘ ] (empty)
            [
                ("", 0, 0, true),
                (showDiagonalKeys ? "↙" : "", downLeftCodes.0, downLeftCodes.1, !showDiagonalKeys),
                ("↓", -2, 0, false),
                (showDiagonalKeys ? "↘" : "", downRightCodes.0, downRightCodes.1, !showDiagonalKeys),
                ("", 0, 0, true)
            ]
        ]

        populateGrid(layout)
    }

    // ============================================================
    // MARK: - Layout 2: Bàn phím số (Numpad Phone 0-9, *, #)
    // ============================================================

    private func buildNumpadLayout() {
        // Standard phone numpad layout:
        // Row 1: 1 (49), 2 (50), 3 (51)
        // Row 2: 4 (52), 5 (53), 6 (54)
        // Row 3: 7 (55), 8 (56), 9 (57)
        // Row 4: * (42), 0 (48), # (35)
        let layout: [[(title: String, c1: Int32, c2: Int32, isEmpty: Bool)]] = [
            [
                ("1", 49, 0, false),
                ("2", 50, 0, false),
                ("3", 51, 0, false)
            ],
            [
                ("4", 52, 0, false),
                ("5", 53, 0, false),
                ("6", 54, 0, false)
            ],
            [
                ("7", 55, 0, false),
                ("8", 56, 0, false),
                ("9", 57, 0, false)
            ],
            [
                ("*", 42, 0, false),
                ("0", 48, 0, false),
                ("#", 35, 0, false)
            ]
        ]
        populateGrid(layout)
    }

    // ============================================================
    // MARK: - Layout 3: Kết hợp (Combined: Numpad + Arrows)
    // ============================================================

    private func buildCombinedLayout() {
        let layout: [[(title: String, c1: Int32, c2: Int32, isEmpty: Bool)]] = [
            [
                ("1", 49, 0, false),
                ("2", 50, 0, false),
                ("3", 51, 0, false),
                ("↑", -1, 0, false),
                ("L", -6, 0, false)
            ],
            [
                ("4", 52, 0, false),
                ("5", 53, 0, false),
                ("6", 54, 0, false),
                ("F", -5, 0, false),
                ("R", -7, 0, false)
            ],
            [
                ("7", 55, 0, false),
                ("8", 56, 0, false),
                ("9", 57, 0, false),
                ("↓", -2, 0, false),
                ("#", 35, 0, false)
            ]
        ]
        populateGrid(layout)
    }

    private func populateGrid(_ layout: [[(title: String, c1: Int32, c2: Int32, isEmpty: Bool)]]) {
        let glyphColor = UIColor(red: 0.43, green: 0.49, blue: 0.66, alpha: 1.0)

        for row in layout {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 8

            for item in row {
                if item.isEmpty {
                    let spacer = UIView()
                    spacer.backgroundColor = .clear
                    spacer.isUserInteractionEnabled = false
                    rowStack.addArrangedSubview(spacer)
                    continue
                }

                let btn = DecadeKeyButton(c1: item.c1, c2: item.c2)
                btn.setTitle(item.title, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
                btn.setTitleColor(glyphColor, for: .normal)
                btn.backgroundColor = UIColor(white: 1.0, alpha: keypadAlphaValue)
                btn.layer.cornerRadius = 12
                btn.layer.borderWidth = 1.0
                btn.layer.borderColor = UIColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 0.60).cgColor

                btn.layer.shadowColor = UIColor(red: 0.2, green: 0.25, blue: 0.35, alpha: 0.12).cgColor
                btn.layer.shadowOffset = CGSize(width: 0, height: 1.5)
                btn.layer.shadowRadius = 2.0
                btn.layer.shadowOpacity = 1.0

                btn.addTarget(self, action: #selector(buttonDown(_:)), for: .touchDown)
                btn.addTarget(self, action: #selector(buttonUp(_:)),
                              for: [.touchUpInside, .touchUpOutside, .touchCancel])

                rowStack.addArrangedSubview(btn)
            }
            mainStack.addArrangedSubview(rowStack)
        }
    }

    @objc private func buttonDown(_ sender: DecadeKeyButton) {
        haptic.impactOccurred(intensity: 0.6)
        activeCode1 = sender.c1
        activeCode2 = sender.c2

        sender.backgroundColor = UIColor(white: 1.0, alpha: 0.95)
        sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        sendKey(pressed: true)

        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
    }

    @objc private func buttonUp(_ sender: DecadeKeyButton) {
        repeatTimer?.invalidate()
        repeatTimer = nil

        UIView.animate(withDuration: 0.1) { [weak self] in
            sender.backgroundColor = UIColor(white: 1.0, alpha: self?.keypadAlphaValue ?? 0.70)
            sender.transform = .identity
        }

        sendKey(pressed: false)
        activeCode1 = 0
        activeCode2 = 0
    }

    private func startRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, self.activeCode1 != 0 else { return }
            self.sendKey(pressed: true)
            usleep(15000)
            self.sendKey(pressed: false)
        }
    }

    private func sendKey(pressed: Bool) {
        let eventType = pressed ? Int32(J2ME_INPUT_KEY_PRESSED) : Int32(J2ME_INPUT_KEY_RELEASED)
        if activeCode1 != 0 {
            j2me_input_post_key(eventType, activeCode1)
        }
        if activeCode2 != 0 {
            j2me_input_post_key(eventType, activeCode2)
        }
    }
}

// Custom UIButton holding keycodes
private class DecadeKeyButton: UIButton {
    let c1: Int32
    let c2: Int32

    init(c1: Int32, c2: Int32) {
        self.c1 = c1
        self.c2 = c2
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }
}
