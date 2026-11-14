//
//  GameViewController.swift
//  J2MEEmulator
//
//  Runs a single J2ME MIDlet with authentic KamenRider Decade / TestFlight UI:
//  - Portrait mode locked with dark top bar (tabs [1], [2], [+], [-], [⌨], [⋮])
//  - Full-screen high-resolution Canvas between top bar and keypad
//  - Authentic on-screen virtual keypad matching TestFlight J2ME / NSO:
//      Col 1-2: F1, F2 / HP, MP / Tab, Size (or Numpad)
//      Col 3-5: 8-way directional pad + OK (1, 2, 3 / 4, 5, 6 / 7, 8, 9)
//  - Native Text Input Dialog (⌨) for effortless typing of username, password, or chat
//

import UIKit

// MARK: - Layout mode

enum GameLayoutMode {
    case decade     // Portrait: Decade/TestFlight top bar, edge-to-edge canvas, clean white keypad
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

    // Decade/TestFlight UI components
    private var decadeKeypadView: DecadeKeypadView?
    private let topBar = UIView()
    private let tabStrip = UIStackView()
    private let textInputBtn = UIButton(type: .system)
    private let menuBtn = UIButton(type: .system)
    private let addTabBtn = UIButton(type: .system)
    private let removeTabBtn = UIButton(type: .system)

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

    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

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
        view.backgroundColor = .black

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

        // Double-tap on canvas triggers Text Input Dialog
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
    // MARK: - Decade / TestFlight Portrait Layout
    // ============================================================

    private func setupDecadeLayout() {
        // 1. Top Bar matching TestFlight reference (Dark Navy #182232)
        topBar.backgroundColor = UIColor(red: 0.09, green: 0.13, blue: 0.20, alpha: 1.0)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        // Tab strip on left
        tabStrip.axis = .horizontal
        tabStrip.spacing = 6
        tabStrip.alignment = .center
        tabStrip.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(tabStrip)

        // Active blue tab "1"
        let tab1 = UIButton(type: .system)
        tab1.setTitle("1", for: .normal)
        tab1.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        tab1.setTitleColor(.white, for: .normal)
        tab1.backgroundColor = UIColor(red: 0.12, green: 0.41, blue: 0.82, alpha: 1.0) // #1E69D2
        tab1.layer.cornerRadius = 5
        tab1.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        tabStrip.addArrangedSubview(tab1)

        // Action buttons on right: [⌨] [−] [+] [⋮]
        let actionStack = UIStackView()
        actionStack.axis = .horizontal
        actionStack.spacing = 14
        actionStack.alignment = .center
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(actionStack)

        // Menu button [⋮]
        menuBtn.setTitle("⋮", for: .normal)
        menuBtn.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        menuBtn.setTitleColor(.white, for: .normal)
        menuBtn.addTarget(self, action: #selector(showMenu), for: .touchUpInside)

        // Minus tab [−]
        removeTabBtn.setTitle("−", for: .normal)
        removeTabBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        removeTabBtn.setTitleColor(.white, for: .normal)
        removeTabBtn.addTarget(self, action: #selector(tabMinusTapped), for: .touchUpInside)

        // Plus tab [+]
        addTabBtn.setTitle("+", for: .normal)
        addTabBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        addTabBtn.setTitleColor(.white, for: .normal)
        addTabBtn.addTarget(self, action: #selector(tabPlusTapped), for: .touchUpInside)

        // Text input button [⌨]
        textInputBtn.setTitle("⌨", for: .normal)
        textInputBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        textInputBtn.setTitleColor(.white, for: .normal)
        textInputBtn.addTarget(self, action: #selector(promptTextInput), for: .touchUpInside)

        actionStack.addArrangedSubview(textInputBtn)
        actionStack.addArrangedSubview(removeTabBtn)
        actionStack.addArrangedSubview(addTabBtn)
        actionStack.addArrangedSubview(menuBtn)

        // 2. Keypad Panel (Bottom)
        let keypad = DecadeKeypadView()
        keypad.translatesAutoresizingMaskIntoConstraints = false
        keypad.onTextInputTapped = { [weak self] in
            self?.promptTextInput()
        }
        keypad.onMenuTapped = { [weak self] in
            self?.showMenu()
        }
        self.decadeKeypadView = keypad
        view.addSubview(keypad)

        // 3. Canvas Container
        emulatorView.translatesAutoresizingMaskIntoConstraints = false
        emulatorView.backgroundColor = .black
        view.addSubview(emulatorView)

        for v: UIView in [formView, listView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
            v.isHidden = true
        }

        NSLayoutConstraint.activate([
            // Top Bar
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            tabStrip.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            tabStrip.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            actionStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            actionStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            // Keypad at bottom matching TestFlight size
            keypad.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keypad.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keypad.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keypad.heightAnchor.constraint(equalToConstant: 255),

            // Game Canvas fills the area between Top Bar and Keypad
            emulatorView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            emulatorView.bottomAnchor.constraint(equalTo: keypad.topAnchor),
            emulatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emulatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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

        view.bringSubviewToFront(topBar)
        view.bringSubviewToFront(keypad)
        view.bringSubviewToFront(formView)
        view.bringSubviewToFront(listView)
    }

    @objc private func tabPlusTapped() {
        let alert = UIAlertController(title: "Đa Tab", message: "Đang chạy Tab 1 (Chính). Tính năng mở thêm Tab song song đang được hoàn thiện.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func tabMinusTapped() {
        let alert = UIAlertController(title: "Đóng Tab", message: "Bạn có muốn thoát game về danh sách?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Thoát", style: .destructive) { [weak self] _ in
            self?.backTapped()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func showMenu() {
        let sheet = UIAlertController(title: "Menu", message: appName, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "⌨ Nhập tài khoản / Mật khẩu / Chat", style: .default) { [weak self] _ in
            self?.promptTextInput()
        })
        sheet.addAction(UIAlertAction(title: "✕ Thoát về danh sách Game", style: .destructive) { [weak self] _ in
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
            message: "Gõ tài khoản, mật khẩu hoặc tin nhắn chat:",
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
        topBar.isHidden = false
        joystickView?.isHidden = false
        numpadView?.isHidden = false
        lskButton.isHidden = false
        rskButton.isHidden = false
        formView.isHidden = true
        listView.isHidden = true
    }

    func showFormView() {
        formView.buildFromNativeData()
        formView.isHidden = false
        emulatorView.isHidden = true
        decadeKeypadView?.isHidden = true
        topBar.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        lskButton.isHidden = true
        rskButton.isHidden = true
        listView.isHidden = true
        view.bringSubviewToFront(formView)
        view.bringSubviewToFront(backButton)
    }

    func showListView() {
        listView.buildFromNativeData()
        listView.isHidden = false
        emulatorView.isHidden = true
        decadeKeypadView?.isHidden = true
        topBar.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        lskButton.isHidden = true
        rskButton.isHidden = true
        formView.isHidden = true
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
