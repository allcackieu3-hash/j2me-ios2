//
//  DecadeKeypadView.swift
//  J2MEEmulator
//
//  1:1 Authentic KamenRider Decade virtual keypad:
//  - Frosted silver/gray background (#ECEFF3)
//  - Translucent rounded white buttons with slate lavender glyphs (#6D7CA8)
//  - Exact 5 columns x 3 rows matching Android KamenRider Decade:
//      Row 1: [ L ]  [ ↖ ]  [ ↑ ]  [ ↗ ]  [ R ]
//      Row 2: (empty) [ ← ]  [ F ]  [ → ] (empty)
//      Row 3: (empty) [ ↙ ]  [ ↓ ]  [ ↘ ] (empty)
//

import UIKit

class DecadeKeypadView: UIView {

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var repeatTimer: Timer?
    private var activeKeyCode: Int32 = 0
    private var activeSecondaryCode: Int32 = 0

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
        // Frosted silver/gray background matching Android Decade (#ECEFF3)
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

        buildButtons()
    }

    private func buildButtons() {
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Authentic Decade layout:
        // Item is (title, primaryKeyCode, secondaryKeyCode, isEmpty)
        let layout: [[(title: String, code: Int32, secCode: Int32, isEmpty: Bool)]] = [
            // Row 1: [ L ]  [ ↖ ]  [ ↑ ]  [ ↗ ]  [ R ]
            [
                ("L", -6, 0, false),
                ("↖", 49, 0, false),
                ("↑", 50, -1, false),
                ("↗", 51, 0, false),
                ("R", -7, 0, false)
            ],
            // Row 2: (empty) [ ← ]  [ F ]  [ → ] (empty)
            [
                ("", 0, 0, true),
                ("←", 52, -3, false),
                ("F", 53, -5, false),
                ("→", 54, -4, false),
                ("", 0, 0, true)
            ],
            // Row 3: (empty) [ ↙ ]  [ ↓ ]  [ ↘ ] (empty)
            [
                ("", 0, 0, true),
                ("↙", 55, 0, false),
                ("↓", 56, -2, false),
                ("↘", 57, 0, false),
                ("", 0, 0, true)
            ]
        ]

        let glyphColor = UIColor(red: 0.43, green: 0.49, blue: 0.66, alpha: 1.0) // Slate Lavender #6D7CA8

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

                let btn = DecadeKeyButton(primaryCode: item.code, secCode: item.secCode)
                btn.setTitle(item.title, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
                btn.setTitleColor(glyphColor, for: .normal)
                btn.backgroundColor = UIColor(white: 1.0, alpha: 0.70)
                btn.layer.cornerRadius = 12
                btn.layer.borderWidth = 1.0
                btn.layer.borderColor = UIColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 0.60).cgColor

                // Soft shadow for elevation
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
        activeKeyCode = sender.primaryCode
        activeSecondaryCode = sender.secCode

        // Press down highlight
        sender.backgroundColor = UIColor(white: 1.0, alpha: 0.95)
        sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        // Post key press
        sendKey(pressed: true)

        // Repeat timer for holding down
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
    }

    @objc private func buttonUp(_ sender: DecadeKeyButton) {
        repeatTimer?.invalidate()
        repeatTimer = nil

        // Release highlight
        UIView.animate(withDuration: 0.1) {
            sender.backgroundColor = UIColor(white: 1.0, alpha: 0.70)
            sender.transform = .identity
        }

        // Post key release
        sendKey(pressed: false)
        activeKeyCode = 0
        activeSecondaryCode = 0
    }

    private func startRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, self.activeKeyCode != 0 else { return }
            self.sendKey(pressed: true)
            usleep(15000)
            self.sendKey(pressed: false)
        }
    }

    private func sendKey(pressed: Bool) {
        guard activeKeyCode != 0 else { return }
        let eventType = pressed ? Int32(J2ME_INPUT_KEY_PRESSED) : Int32(J2ME_INPUT_KEY_RELEASED)
        j2me_input_post_key(eventType, activeKeyCode)
        if activeSecondaryCode != 0 {
            j2me_input_post_key(eventType, activeSecondaryCode)
        }
    }
}

// Custom UIButton holding keycodes
private class DecadeKeyButton: UIButton {
    let primaryCode: Int32
    let secCode: Int32

    init(primaryCode: Int32, secCode: Int32) {
        self.primaryCode = primaryCode
        self.secCode = secCode
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }
}
