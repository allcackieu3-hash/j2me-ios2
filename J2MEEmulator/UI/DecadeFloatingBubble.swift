//
//  DecadeFloatingBubble.swift
//  J2MEEmulator
//
//  Authentic AssistiveTouch-style floating draggable bubble & popup menu for "Ẩn ứng dụng"
//  matching Android Decade & iOS AssistiveTouch behavior.
//

import UIKit

final class DecadeFloatingBubble: UIView {
    static let shared = DecadeFloatingBubble()

    var onRestoreGame: (() -> Void)?
    var onSwitchTab: ((Int) -> Void)?
    var onAssignProxy: (() -> Void)?
    var onToggleTreo: (() -> Void)?
    var onToggleHeadless: (() -> Void)?
    var onSelectTabPrompt: (() -> Void)?
    var onTogglePiP: (() -> Void)?

    private let iconImageView = UIImageView()
    private let badgeLabel = UILabel()
    private var isDragging = false
    private var autoDimWorkItem: DispatchWorkItem?

    // AssistiveTouch Popup Container & Backdrop
    private var menuBackdropView: UIView?
    private var menuCardView: UIView?
    private(set) var isMenuOpen = false

    private var currentAppName: String = "J2ME Game"
    private var currentTabNumber: Int = 1

    private init() {
        let size: CGFloat = 58
        super.init(frame: CGRect(x: UIScreen.main.bounds.width - size - 10, y: 200, width: size, height: size))
        setupBubbleUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBubbleUI() {
        backgroundColor = UIColor(white: 0.12, alpha: 0.90)
        layer.cornerRadius = 29
        layer.borderWidth = 2.5
        layer.borderColor = UIColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 0.95).cgColor // Neon cyan #00E5FF
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        clipsToBounds = false

        // Default to the ninja bubble_logo matching Decade Android
        let defaultImg = UIImage(named: "bubble_logo") ?? UIImage(named: "DecadeLogo") ?? UIImage(systemName: "gamecontroller.fill")
        iconImageView.image = defaultImg
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 24
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        badgeLabel.text = "1"
        badgeLabel.font = .systemFont(ofSize: 12, weight: .heavy)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor(red: 0.12, green: 0.45, blue: 0.90, alpha: 1.0) // Decade Blue
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.layer.borderWidth = 1.5
        badgeLabel.layer.borderColor = UIColor.white.cgColor
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: -4),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    func setGameInfo(name: String, icon: UIImage?, tabNumber: Int) {
        self.currentAppName = name
        self.currentTabNumber = tabNumber
        badgeLabel.text = "\(tabNumber)"
        if let icon = icon {
            iconImageView.image = icon
        } else if let bubbleLogo = UIImage(named: "bubble_logo") {
            iconImageView.image = bubbleLogo
        }
    }

    func setTabBadge(_ tabNumber: Int) {
        self.currentTabNumber = tabNumber
        badgeLabel.text = "\(tabNumber)"
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    func show(in window: UIWindow?) {
        guard let win = window ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        if superview == nil {
            win.addSubview(self)
        }
        win.bringSubviewToFront(self)
        alpha = 0
        isHidden = false
        transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.alpha = 1.0
            self.transform = .identity
        }
        scheduleAutoDim()
    }

    func hide() {
        dismissAssistiveTouchMenu(animated: false)
        autoDimWorkItem?.cancel()
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in
            self.isHidden = true
            self.removeFromSuperview()
        }
    }

    // ============================================================
    // MARK: - Dragging & Snapping (AssistiveTouch style)
    // ============================================================

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let win = superview else { return }
        let translation = gesture.translation(in: win)

        switch gesture.state {
        case .began:
            isDragging = true
            autoDimWorkItem?.cancel()
            UIView.animate(withDuration: 0.1) {
                self.alpha = 1.0
                self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            }
        case .changed:
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: win)
        case .ended, .cancelled:
            isDragging = false
            snapToEdge(in: win)
            scheduleAutoDim()
        default:
            break
        }
    }

    private func snapToEdge(in container: UIView) {
        let safeArea = container.safeAreaInsets
        let midX = container.bounds.midX
        let targetX: CGFloat = center.x < midX ? safeArea.left + bounds.width / 2 + 8 : container.bounds.width - safeArea.right - bounds.width / 2 - 8

        let minY = safeArea.top + bounds.height / 2 + 10
        let maxY = container.bounds.height - safeArea.bottom - bounds.height / 2 - 10
        let targetY = min(max(center.y, minY), maxY)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            self.center = CGPoint(x: targetX, y: targetY)
            self.transform = .identity
            self.alpha = 0.90
        }
    }

    private func scheduleAutoDim() {
        autoDimWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isDragging, !self.isMenuOpen else { return }
            UIView.animate(withDuration: 0.3) {
                self.alpha = 0.55
            }
        }
        autoDimWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    // ============================================================
    // MARK: - AssistiveTouch Popup Menu (Nút Home ảo)
    // ============================================================

    @objc private func handleTap() {
        if isMenuOpen {
            dismissAssistiveTouchMenu(animated: true)
        } else {
            showAssistiveTouchMenu()
        }
    }

    private func showAssistiveTouchMenu() {
        guard let win = superview ?? window ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        isMenuOpen = true
        autoDimWorkItem?.cancel()
        alpha = 1.0

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // 1. Transparent dismiss backdrop
        let backdrop = UIView(frame: win.bounds)
        backdrop.backgroundColor = UIColor(white: 0, alpha: 0.35)
        backdrop.alpha = 0
        let tapBackdrop = UITapGestureRecognizer(target: self, action: #selector(backdropTapped))
        backdrop.addGestureRecognizer(tapBackdrop)
        win.addSubview(backdrop)
        self.menuBackdropView = backdrop

        // 2. AssistiveTouch Dark Glass Menu Card
        let cardWidth: CGFloat = 290
        let cardHeight: CGFloat = 270
        let card = UIView()
        card.backgroundColor = .clear
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.50
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.layer.shadowRadius = 16
        card.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false
        win.addSubview(card)
        self.menuCardView = card

        // Visual blur effect (systemMaterialDark)
        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 24
        blurView.layer.borderWidth = 1.0
        blurView.layer.borderColor = UIColor(white: 1.0, alpha: 0.20).cgColor
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(blurView)

        // Content Stack
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .fill
        contentStack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)

        // Header: Icon + Title + Tab Badge
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 10
        headerStack.alignment = .center

        let headerIcon = UIImageView()
        headerIcon.image = iconImageView.image
        headerIcon.contentMode = .scaleAspectFill
        headerIcon.layer.cornerRadius = 14
        headerIcon.clipsToBounds = true
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        headerIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        headerStack.addArrangedSubview(headerIcon)

        let titleLabel = UILabel()
        titleLabel.text = currentAppName
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .white
        headerStack.addArrangedSubview(titleLabel)

        let tabPill = UILabel()
        tabPill.text = " Tab \(currentTabNumber) "
        tabPill.font = .systemFont(ofSize: 11, weight: .heavy)
        tabPill.textColor = .white
        tabPill.backgroundColor = UIColor(red: 0.12, green: 0.45, blue: 0.90, alpha: 1.0)
        tabPill.layer.cornerRadius = 8
        tabPill.clipsToBounds = true
        headerStack.addArrangedSubview(tabPill)

        contentStack.addArrangedSubview(headerStack)

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        contentStack.addArrangedSubview(sep)

        // Grid of 6 AssistiveTouch circular action items (2 rows x 3 columns)
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.distribution = .fillEqually
        row1.spacing = 8

        let isTreo = DecadeBackgroundKeeper.shared.isTreoActive
        let btnGame = makeAssistiveItem(icon: "🎮", title: "Mở game", tag: 1)
        let btnPiP = makeAssistiveItem(icon: "📺", title: "Bóng ngoài", tag: 7, isActive: DecadePiPManager.shared.isPiPActive)
        let btnProxy = makeAssistiveItem(icon: "🌐", title: "Gán proxy", tag: 3)
        row1.addArrangedSubview(btnGame)
        row1.addArrangedSubview(btnPiP)
        row1.addArrangedSubview(btnProxy)

        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.distribution = .fillEqually
        row2.spacing = 8

        let btnTabs = makeAssistiveItem(icon: "📋", title: "Đổi tab", tag: 4)
        let btnTreo = makeAssistiveItem(icon: isTreo ? "✓🌙" : "🌙", title: "Treo tắt màn", tag: 2, isActive: isTreo)
        let btnClose = makeAssistiveItem(icon: "✕", title: "Đóng bóng", tag: 6, isDestructive: true)
        row2.addArrangedSubview(btnTabs)
        row2.addArrangedSubview(btnTreo)
        row2.addArrangedSubview(btnClose)

        contentStack.addArrangedSubview(row1)
        contentStack.addArrangedSubview(row2)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: card.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: card.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: win.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: win.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: cardWidth),
            card.heightAnchor.constraint(equalToConstant: cardHeight),
        ])

        // Animate menu popping up from center
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.6) {
            backdrop.alpha = 1.0
            card.alpha = 1.0
            card.transform = .identity
        }
    }

    private func makeAssistiveItem(icon: String, title: String, tag: Int, isActive: Bool = false, isDestructive: Bool = false) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let circleBtn = UIButton(type: .custom)
        circleBtn.setTitle(icon, for: .normal)
        circleBtn.titleLabel?.font = .systemFont(ofSize: 22)
        circleBtn.layer.cornerRadius = 24
        circleBtn.translatesAutoresizingMaskIntoConstraints = false

        if isDestructive {
            circleBtn.backgroundColor = UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 0.35)
            circleBtn.layer.borderWidth = 1.5
            circleBtn.layer.borderColor = UIColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 0.8).cgColor
        } else if isActive {
            circleBtn.backgroundColor = UIColor(red: 0.12, green: 0.75, blue: 0.35, alpha: 0.35)
            circleBtn.layer.borderWidth = 1.5
            circleBtn.layer.borderColor = UIColor(red: 0.20, green: 0.90, blue: 0.40, alpha: 0.9).cgColor
        } else {
            circleBtn.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
            circleBtn.layer.borderWidth = 1.0
            circleBtn.layer.borderColor = UIColor(white: 1.0, alpha: 0.25).cgColor
        }

        circleBtn.tag = tag
        circleBtn.addTarget(self, action: #selector(assistiveItemTapped(_:)), for: .touchUpInside)
        container.addSubview(circleBtn)

        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = isDestructive ? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0) : UIColor(white: 0.92, alpha: 1.0)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)

        NSLayoutConstraint.activate([
            circleBtn.topAnchor.constraint(equalTo: container.topAnchor),
            circleBtn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circleBtn.widthAnchor.constraint(equalToConstant: 48),
            circleBtn.heightAnchor.constraint(equalToConstant: 48),

            lbl.topAnchor.constraint(equalTo: circleBtn.bottomAnchor, constant: 4),
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            lbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            lbl.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    @objc private func assistiveItemTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismissAssistiveTouchMenu(animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            switch sender.tag {
            case 1:
                self.onRestoreGame?()
            case 2:
                self.onToggleTreo?()
            case 3:
                self.onAssignProxy?()
            case 4:
                self.onSelectTabPrompt?()
            case 5:
                self.onToggleHeadless?()
            case 6:
                self.hide()
            case 7:
                self.onTogglePiP?()
            default:
                break
            }
        }
    }

    @objc private func backdropTapped() {
        dismissAssistiveTouchMenu(animated: true)
    }

    func dismissAssistiveTouchMenu(animated: Bool) {
        guard isMenuOpen else { return }
        isMenuOpen = false

        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.menuBackdropView?.alpha = 0
                self.menuCardView?.alpha = 0
                self.menuCardView?.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            }) { _ in
                self.menuBackdropView?.removeFromSuperview()
                self.menuCardView?.removeFromSuperview()
                self.menuBackdropView = nil
                self.menuCardView = nil
            }
        } else {
            menuBackdropView?.removeFromSuperview()
            menuCardView?.removeFromSuperview()
            menuBackdropView = nil
            menuCardView = nil
        }
        scheduleAutoDim()
    }
}
