//
//  GameViewController.swift
//  J2MEEmulator
//
//  Runs a single J2ME MIDlet with authentic KamenRider Decade UI:
//  - Portrait mode locked with Decade top bar & multi-tab switcher
//  - Centered high-resolution Canvas with touch support & double-tap text prompt
//  - Authentic Decade on-screen virtual keypad (8-way directional, numpad, soft keys, backspace)
//  - Full-featured Text Input Dialog (⌨) for effortlessly entering username, password, or chat
//

import UIKit

// MARK: - Layout mode

enum GameLayoutMode {
    case decade     // Portrait: Decade top bar, centered screen, Decade virtual keypad
    case ngage      // Landscape: D-pad left, screen center, numpad right
}

// MARK: - GameViewController

class GameViewController: UIViewController {

    let jarPath: String
    let appName: String
    let appIcon: UIImage
    let canvasWidth: Int
    let canvasHeight: Int
    let render3dScale: Int
    let fpsLimit: Int
    let layoutMode: GameLayoutMode

    private let gameContainerView = UIView()
    private let emulatorView = EmulatorView()
    private let glowContainer = UIView()
    private let glowContentView = UIView()
    private lazy var formView = FormView()
    private lazy var listView = J2MEListView()
    private let backButton = UIButton(type: .system)
    private let lskButton = UIButton(type: .system)
    private let rskButton = UIButton(type: .system)
    private let softKeyHaptic = UIImpactFeedbackGenerator(style: .light)
    private(set) var placeholderIconView: UIImageView?

    // Decade UI components
    private var decadeKeypadView: DecadeKeypadView?
    private let decadeTopBar = UIView()
    private let tabStackView = UIStackView()
    private let textInputTopBtn = UIButton(type: .system)

    // Legacy controls (if in ngage mode)
    private var joystickView: JoystickView?
    private var numpadView: NumpadView?

    init(jarPath: String, appName: String, appIcon: UIImage,
         canvasWidth: Int = 240, canvasHeight: Int = 320,
         render3dScale: Int = 3, fpsLimit: Int = 0,
         layoutMode: GameLayoutMode = .decade) {
        self.jarPath = jarPath
        self.appName = appName
        self.appIcon = appIcon
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.render3dScale = render3dScale
        self.fpsLimit = fpsLimit
        self.layoutMode = layoutMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        setGlobalEmulatorView(nil)
        alertTimeoutWork?.cancel()
    }

    private var alertTimeoutWork: DispatchWorkItem?

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch layoutMode {
        case .decade: return .portrait
        case .ngage: return .landscape
        }
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        switch layoutMode {
        case .decade: return .portrait
        case .ngage: return .landscapeRight
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)

        emulatorView.canvasWidth = canvasWidth
        emulatorView.canvasHeight = canvasHeight

        switch layoutMode {
        case .decade:
            setupDecadeLayout()
        case .ngage:
            setupNGageLayout()
        }

        // Placeholder icon — visible until first game frame
        let iconIV = UIImageView(image: appIcon)
        iconIV.contentMode = .center
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconIV)
        NSLayoutConstraint.activate([
            iconIV.centerXAnchor.constraint(equalTo: emulatorView.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: emulatorView.centerYAnchor),
        ])
        placeholderIconView = iconIV
        view.bringSubviewToFront(backButton)

        // Fade out placeholder on first rendered frame
        emulatorView.onFirstFrame = { [weak self] in
            guard let icon = self?.placeholderIconView else { return }
            UIView.animate(withDuration: 0.2) {
                icon.alpha = 0
            } completion: { _ in
                icon.removeFromSuperview()
                self?.placeholderIconView = nil
            }
        }

        // Mirror game frames to glow layer
        emulatorView.onFrame = { [weak self] cgImage in
            self?.glowContentView.layer.contents = cgImage
        }

        // Double-tap on canvas triggers Text Input Dialog without delaying single taps
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(canvasDoubleTapped))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delaysTouchesBegan = false
        doubleTap.cancelsTouchesInView = false
        emulatorView.addGestureRecognizer(doubleTap)

        // Register native callbacks
        setGlobalEmulatorView(emulatorView)
        j2me_render_set_flush_callback(flushCallback)
        j2me_ui_set_callback(gameUICallback)
        activeGameViewController = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startGame()
    }

    // ============================================================
    // MARK: - KamenRider Decade Portrait Layout
    // ============================================================

    private func setupDecadeLayout() {
        // 1. Top Decade Bar (Navy Blue #1C2534)
        decadeTopBar.backgroundColor = UIColor(red: 0.11, green: 0.15, blue: 0.21, alpha: 1.0)
        decadeTopBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(decadeTopBar)

        let magentaLine = UIView()
        magentaLine.backgroundColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0)
        magentaLine.translatesAutoresizingMaskIntoConstraints = false
        decadeTopBar.addSubview(magentaLine)

        // Back button
        backButton.setTitle(" ✕ ", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        backButton.setTitleColor(.white, for: .normal)
        backButton.backgroundColor = UIColor(white: 0.18, alpha: 0.9)
        backButton.layer.cornerRadius = 8
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = UIColor(white: 0.35, alpha: 0.4).cgColor
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        decadeTopBar.addSubview(backButton)

        // Multi-Tab bar in center
        tabStackView.axis = .horizontal
        tabStackView.spacing = 6
        tabStackView.distribution = .fillProportionally
        tabStackView.translatesAutoresizingMaskIntoConstraints = false
        decadeTopBar.addSubview(tabStackView)

        let tab1 = createTabButton(title: "Tab 1", isActive: true)
        let tab2 = createTabButton(title: "Tab 2", isActive: false)
        let addTab = createTabButton(title: " + ", isActive: false)
        tabStackView.addArrangedSubview(tab1)
        tabStackView.addArrangedSubview(tab2)
        tabStackView.addArrangedSubview(addTab)

        // Top right text input button
        textInputTopBtn.setTitle(" ⌨ Nhập ", for: .normal)
        textInputTopBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        textInputTopBtn.setTitleColor(.white, for: .normal)
        textInputTopBtn.backgroundColor = UIColor(red: 0.05, green: 0.50, blue: 0.45, alpha: 1.0)
        textInputTopBtn.layer.cornerRadius = 8
        textInputTopBtn.layer.borderWidth = 1
        textInputTopBtn.layer.borderColor = UIColor(red: 0.10, green: 0.70, blue: 0.60, alpha: 0.6).cgColor
        textInputTopBtn.addTarget(self, action: #selector(promptTextInput), for: .touchUpInside)
        textInputTopBtn.translatesAutoresizingMaskIntoConstraints = false
        decadeTopBar.addSubview(textInputTopBtn)

        // 2. Keypad Panel (Bottom)
        let keypad = DecadeKeypadView()
        keypad.translatesAutoresizingMaskIntoConstraints = false
        keypad.onTextInputTapped = { [weak self] in
            self?.promptTextInput()
        }
        keypad.onMenuTapped = { [weak self] in
            self?.showDecadeMenu()
        }
        keypad.onTabTapped = { [weak self] slot in
            self?.handleTabTapped(slot)
        }
        self.decadeKeypadView = keypad
        view.addSubview(keypad)

        // 3. Canvas Container & Glow
        gameContainerView.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.backgroundColor = .black
        view.addSubview(gameContainerView)

        glowContainer.isUserInteractionEnabled = false
        glowContainer.clipsToBounds = true
        glowContentView.layer.magnificationFilter = .trilinear
        glowContentView.layer.minificationFilter = .trilinear
        glowContentView.alpha = 0.5
        glowContainer.addSubview(glowContentView)

        glowContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glowContentView.topAnchor.constraint(equalTo: glowContainer.topAnchor),
            glowContentView.leadingAnchor.constraint(equalTo: glowContainer.leadingAnchor),
            glowContentView.trailingAnchor.constraint(equalTo: glowContainer.trailingAnchor),
            glowContentView.bottomAnchor.constraint(equalTo: glowContainer.bottomAnchor),
        ])

        let glowBlur = NeutralBlurView(radius: 60)
        glowBlur.isUserInteractionEnabled = false

        for v: UIView in [glowContainer, glowBlur, emulatorView, formView, listView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        formView.isHidden = true
        listView.isHidden = true

        let canvasRatio: CGFloat = CGFloat(emulatorView.canvasWidth) / CGFloat(emulatorView.canvasHeight)

        let wRatio = emulatorView.widthAnchor.constraint(equalTo: emulatorView.heightAnchor, multiplier: canvasRatio)
        wRatio.priority = .defaultHigh

        let hRatio = emulatorView.heightAnchor.constraint(equalTo: emulatorView.widthAnchor, multiplier: 1.0 / canvasRatio)
        hRatio.priority = .defaultLow

        NSLayoutConstraint.activate([
            // Top Bar
            decadeTopBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            decadeTopBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            decadeTopBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            decadeTopBar.heightAnchor.constraint(equalToConstant: 44),

            magentaLine.leadingAnchor.constraint(equalTo: decadeTopBar.leadingAnchor),
            magentaLine.trailingAnchor.constraint(equalTo: decadeTopBar.trailingAnchor),
            magentaLine.bottomAnchor.constraint(equalTo: decadeTopBar.bottomAnchor),
            magentaLine.heightAnchor.constraint(equalToConstant: 2),

            backButton.leadingAnchor.constraint(equalTo: decadeTopBar.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: decadeTopBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 38),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            tabStackView.centerXAnchor.constraint(equalTo: decadeTopBar.centerXAnchor),
            tabStackView.centerYAnchor.constraint(equalTo: decadeTopBar.centerYAnchor),
            tabStackView.heightAnchor.constraint(equalToConstant: 30),

            textInputTopBtn.trailingAnchor.constraint(equalTo: decadeTopBar.trailingAnchor, constant: -8),
            textInputTopBtn.centerYAnchor.constraint(equalTo: decadeTopBar.centerYAnchor),
            textInputTopBtn.heightAnchor.constraint(equalToConstant: 32),

            // Keypad at bottom
            keypad.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keypad.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keypad.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keypad.heightAnchor.constraint(equalToConstant: 245),

            // Game Container in center
            gameContainerView.topAnchor.constraint(equalTo: decadeTopBar.bottomAnchor, constant: 4),
            gameContainerView.bottomAnchor.constraint(equalTo: keypad.topAnchor, constant: -4),
            gameContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            gameContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),

            // Game Canvas aspect-fit centered inside container
            emulatorView.centerXAnchor.constraint(equalTo: gameContainerView.centerXAnchor),
            emulatorView.centerYAnchor.constraint(equalTo: gameContainerView.centerYAnchor),
            emulatorView.widthAnchor.constraint(lessThanOrEqualTo: gameContainerView.widthAnchor),
            emulatorView.heightAnchor.constraint(lessThanOrEqualTo: gameContainerView.heightAnchor),
            wRatio,
            hRatio,

            // Glow container
            glowContainer.centerXAnchor.constraint(equalTo: emulatorView.centerXAnchor),
            glowContainer.centerYAnchor.constraint(equalTo: emulatorView.centerYAnchor),
            glowContainer.widthAnchor.constraint(equalTo: emulatorView.widthAnchor),
            glowContainer.heightAnchor.constraint(equalTo: emulatorView.heightAnchor),

            glowBlur.topAnchor.constraint(equalTo: view.topAnchor),
            glowBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glowBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glowBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Form & List full overlay
            formView.topAnchor.constraint(equalTo: view.topAnchor),
            formView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            formView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            listView.topAnchor.constraint(equalTo: view.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        emulatorView.layer.cornerRadius = 8
        emulatorView.clipsToBounds = true
        emulatorView.layer.borderColor = UIColor(white: 0.35, alpha: 0.5).cgColor
        emulatorView.layer.borderWidth = 1

        view.bringSubviewToFront(keypad)
        view.bringSubviewToFront(decadeTopBar)
        view.bringSubviewToFront(formView)
        view.bringSubviewToFront(listView)
    }

    private func createTabButton(title: String, isActive: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        btn.layer.cornerRadius = 6
        btn.layer.borderWidth = 1
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        if isActive {
            btn.backgroundColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 0.25)
            btn.setTitleColor(UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0), for: .normal)
            btn.layer.borderColor = UIColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 0.8).cgColor
        } else {
            btn.backgroundColor = UIColor(white: 0.14, alpha: 0.8)
            btn.setTitleColor(UIColor(white: 0.7, alpha: 1.0), for: .normal)
            btn.layer.borderColor = UIColor(white: 0.3, alpha: 0.4).cgColor
        }
        return btn
    }

    private func handleTabTapped(_ slot: Int) {
        let alert = UIAlertController(
            title: "Decade Multi-Tab",
            message: slot == 0 ? "Mở thêm Tab mới:" : "Chuyển sang Tab \(slot):",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Đang ở Tab 1 (Chính)", style: .default))
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(alert, animated: true)
    }

    private func showDecadeMenu() {
        let sheet = UIAlertController(title: "KamenRider Decade", message: "Tùy chọn J2ME Decade:", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "⌨ Nhập văn bản (Tài khoản / Chat)", style: .default) { [weak self] _ in
            self?.promptTextInput()
        })
        sheet.addAction(UIAlertAction(title: "✕ Về danh sách Game", style: .destructive) { [weak self] _ in
            self?.backTapped()
        })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(sheet, animated: true)
    }

    // ============================================================
    // MARK: - Text Input Dialog
    // ============================================================

    @objc private func canvasDoubleTapped() {
        promptTextInput()
    }

    @objc func promptTextInput() {
        softKeyHaptic.impactOccurred(intensity: 0.7)
        let alert = UIAlertController(
            title: "⌨ Nhập văn bản vào Game",
            message: "Nhập tài khoản, mật khẩu hoặc chat rồi chọn Gửi:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Gõ nội dung tại đây..."
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
            tf.isSecureTextEntry = false
            tf.clearButtonMode = .whileEditing
            tf.returnKeyType = .send

            // Auto-fill clipboard text if suitable
            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !clip.isEmpty, clip.count <= 64 {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: "Gửi & Enter (↵)", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            self?.sendTextToMIDlet(text, sendEnter: true)
        })
        alert.addAction(UIAlertAction(title: "Chỉ gửi", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            self?.sendTextToMIDlet(text, sendEnter: false)
        })
        alert.addAction(UIAlertAction(title: "⌫ Xóa hết (Clear)", style: .destructive) { [weak self] _ in
            self?.sendClearToMIDlet()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func sendTextToMIDlet(_ text: String, sendEnter: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            for char in text {
                if let scalar = char.unicodeScalars.first {
                    let code = Int32(scalar.value)
                    j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), code)
                    usleep(15000) // 15ms gap
                    j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), code)
                    usleep(15000)
                }
            }
            if sendEnter {
                usleep(50000)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), 53)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), 10)
                usleep(20000)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), 10)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), 53)
            }
        }
    }

    private func sendClearToMIDlet() {
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<30 {
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), 8)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), -8)
                usleep(10000)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), 8)
                j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), -8)
                usleep(10000)
            }
        }
    }

    // ============================================================
    // MARK: - N-Gage Landscape Layout (Fallback)
    // ============================================================

    private func setupNGageLayout() {
        let joystick = JoystickView()
        let numpad = NumpadView()
        self.joystickView = joystick
        self.numpadView = numpad

        glowContainer.isUserInteractionEnabled = false
        glowContainer.clipsToBounds = true

        glowContentView.layer.magnificationFilter = .trilinear
        glowContentView.layer.minificationFilter = .trilinear
        glowContentView.alpha = 0.6
        glowContainer.addSubview(glowContentView)

        glowContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glowContentView.topAnchor.constraint(equalTo: glowContainer.topAnchor),
            glowContentView.leadingAnchor.constraint(equalTo: glowContainer.leadingAnchor),
            glowContentView.trailingAnchor.constraint(equalTo: glowContainer.trailingAnchor),
            glowContentView.bottomAnchor.constraint(equalTo: glowContainer.bottomAnchor),
        ])

        let glowBlur = NeutralBlurView(radius: 100)
        glowBlur.isUserInteractionEnabled = false

        for v: UIView in [glowContainer, glowBlur, joystick, emulatorView, numpad, lskButton, rskButton, formView, listView, backButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        formView.isHidden = true
        listView.isHidden = true

        for (btn, title) in [(lskButton, "L"), (rskButton, "R")] {
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = UIColor(white: 0.12, alpha: 1)
            btn.layer.cornerRadius = 10
            btn.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
            btn.layer.borderWidth = 1
            btn.addTarget(self, action: #selector(softKeyDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(softKeyUp(_:)),
                          for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        lskButton.tag = -6
        rskButton.tag = -7

        backButton.setTitle("  \u{2715}  ", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        backButton.backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        backButton.setTitleColor(.white, for: .normal)
        backButton.layer.cornerRadius = 10
        backButton.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        backButton.layer.borderWidth = 1
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        let canvasRatio: CGFloat = CGFloat(emulatorView.canvasWidth) / CGFloat(emulatorView.canvasHeight)
        let pad: CGFloat = 8

        let leftArea = UILayoutGuide()
        let rightArea = UILayoutGuide()
        view.addLayoutGuide(leftArea)
        view.addLayoutGuide(rightArea)

        NSLayoutConstraint.activate([
            leftArea.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            leftArea.trailingAnchor.constraint(equalTo: emulatorView.leadingAnchor),

            rightArea.leadingAnchor.constraint(equalTo: emulatorView.trailingAnchor),
            rightArea.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            glowContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glowContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            glowContainer.widthAnchor.constraint(equalTo: emulatorView.widthAnchor),
            glowContainer.heightAnchor.constraint(equalTo: emulatorView.heightAnchor),

            glowBlur.topAnchor.constraint(equalTo: view.topAnchor),
            glowBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glowBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glowBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emulatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emulatorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: pad),
            emulatorView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),
            emulatorView.widthAnchor.constraint(equalTo: emulatorView.heightAnchor, multiplier: canvasRatio),

            joystick.centerXAnchor.constraint(equalTo: leftArea.centerXAnchor),
            joystick.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            joystick.widthAnchor.constraint(equalToConstant: 160),
            joystick.heightAnchor.constraint(equalToConstant: 160),

            numpad.trailingAnchor.constraint(equalTo: rightArea.trailingAnchor, constant: -12),
            numpad.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            numpad.widthAnchor.constraint(equalToConstant: 140),
            numpad.heightAnchor.constraint(equalToConstant: 180),

            lskButton.trailingAnchor.constraint(equalTo: emulatorView.leadingAnchor, constant: -6),
            lskButton.bottomAnchor.constraint(equalTo: emulatorView.bottomAnchor),
            lskButton.widthAnchor.constraint(equalToConstant: 68),
            lskButton.heightAnchor.constraint(equalToConstant: 40),

            rskButton.leadingAnchor.constraint(equalTo: emulatorView.trailingAnchor, constant: 6),
            rskButton.bottomAnchor.constraint(equalTo: emulatorView.bottomAnchor),
            rskButton.widthAnchor.constraint(equalToConstant: 68),
            rskButton.heightAnchor.constraint(equalToConstant: 40),

            formView.topAnchor.constraint(equalTo: view.topAnchor),
            formView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            formView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            listView.topAnchor.constraint(equalTo: view.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 4),
        ])

        emulatorView.layer.cornerRadius = 8
        emulatorView.clipsToBounds = true
        emulatorView.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        emulatorView.layer.borderWidth = 1

        view.bringSubviewToFront(formView)
        view.bringSubviewToFront(listView)
        view.bringSubviewToFront(backButton)
    }

    // MARK: - Soft keys

    @objc private func softKeyDown(_ sender: UIButton) {
        softKeyHaptic.impactOccurred(intensity: 0.6)
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), Int32(sender.tag))
        sender.backgroundColor = UIColor(white: 0.30, alpha: 1)
    }

    @objc private func softKeyUp(_ sender: UIButton) {
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), Int32(sender.tag))
        sender.backgroundColor = UIColor(white: 0.12, alpha: 1)
    }

    // ============================================================
    // MARK: - Game lifecycle
    // ============================================================

    private func startGame() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runMIDlet()
            DispatchQueue.main.async {
                self?.dismiss(animated: true)
            }
        }
    }

    private func runMIDlet() {
        guard let resRoot = Bundle.main.resourcePath else { return }
        let docs = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()

        let jarFileName = URL(fileURLWithPath: jarPath).deletingPathExtension().lastPathComponent
        let gameId = jarFileName.replacingOccurrences(of: "[^a-zA-Z0-9._-]",
                                                       with: "_", options: .regularExpression)
        let saveRoot = docs + "/Games Data/" + gameId
        try? FileManager.default.createDirectory(atPath: saveRoot, withIntermediateDirectories: true)

        let initResult = jvm_bridge_init(resRoot, saveRoot, jarPath,
                                         Int32(canvasWidth),
                                         Int32(canvasHeight),
                                         Int32(render3dScale),
                                         Int32(fpsLimit))
        guard initResult == 0 else {
            print("[Swift] ERROR: JVM init failed with code \(initResult)")
            return
        }

        let runResult = jvm_bridge_run_midlet(jarPath)
        print("[Swift] MIDlet run result: \(runResult)")
        jvm_bridge_destroy()
    }

    @objc private func backTapped() {
        backButton.isEnabled = false
        jvm_bridge_request_stop()
    }

    // ============================================================
    // MARK: - View switching
    // ============================================================

    func showCanvasView() {
        emulatorView.isHidden = false
        decadeKeypadView?.isHidden = false
        decadeTopBar.isHidden = false
        joystickView?.isHidden = false
        numpadView?.isHidden = false
        lskButton.isHidden = false
        rskButton.isHidden = false
        formView.isHidden = true
        listView.isHidden = true
    }

    func showFormView() {
        emulatorView.isHidden = true
        decadeKeypadView?.isHidden = true
        decadeTopBar.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        lskButton.isHidden = true
        rskButton.isHidden = true
        formView.isHidden = false
        listView.isHidden = true
        view.bringSubviewToFront(formView)
        view.bringSubviewToFront(backButton)
    }

    func showListView() {
        emulatorView.isHidden = true
        decadeKeypadView?.isHidden = true
        decadeTopBar.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        lskButton.isHidden = true
        rskButton.isHidden = true
        formView.isHidden = true
        listView.isHidden = false
        view.bringSubviewToFront(listView)
        view.bringSubviewToFront(backButton)
    }

    func showAlert() {
        let title = String(cString: j2me_ui_get_form_title())
        let text = String(cString: j2me_ui_get_alert_text())

        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)

        alertTimeoutWork?.cancel()
        alertTimeoutWork = nil

        let cmdCount = j2me_ui_get_command_count()
        if cmdCount == 0 {
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.alertTimeoutWork?.cancel()
                j2me_input_post_key(Int32(J2ME_UI_ALERT_DISMISSED), 0)
            })
        } else {
            for i in 0..<cmdCount {
                let label = String(cString: j2me_ui_get_command_label(Int32(i)))
                let cmdId = j2me_ui_get_command_id(Int32(i))
                alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                    self?.alertTimeoutWork?.cancel()
                    j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), cmdId)
                })
            }
        }

        present(alert, animated: true)

        let timeout = j2me_ui_get_alert_timeout()
        if timeout > 0 {
            let work = DispatchWorkItem { [weak alert] in
                alert?.dismiss(animated: true) {
                    j2me_input_post_key(Int32(J2ME_UI_ALERT_DISMISSED), 0)
                }
            }
            alertTimeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeout) / 1000.0, execute: work)
        }
    }
}

// ============================================================
// Global active GameViewController reference
// ============================================================

private(set) weak var activeGameViewController: GameViewController?

let gameUICallback: @convention(c) (Int32, UnsafePointer<CChar>?) -> Void = { action, data in
    DispatchQueue.main.async {
        guard let vc = activeGameViewController else { return }
        switch action {
        case Int32(J2ME_UI_ACTION_SHOW_CANVAS):  vc.showCanvasView()
        case Int32(J2ME_UI_ACTION_SHOW_FORM):    vc.showFormView()
        case Int32(J2ME_UI_ACTION_SHOW_LIST):    vc.showListView()
        case Int32(J2ME_UI_ACTION_SHOW_ALERT):   vc.showAlert()
        default: break
        }
    }
}
