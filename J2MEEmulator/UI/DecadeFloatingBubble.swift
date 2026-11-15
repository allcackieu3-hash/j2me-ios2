//
//  DecadeFloatingBubble.swift
//  J2MEEmulator
//
//  Authentic AssistiveTouch-style floating draggable bubble for "Ẩn ứng dụng"
//  matching Android Decade Screenshot 3 & 4.
//

import UIKit

final class DecadeFloatingBubble: UIView {
    static let shared = DecadeFloatingBubble()

    var onRestoreGame: (() -> Void)?
    var onSwitchTab: ((Int) -> Void)?
    var onAssignProxy: (() -> Void)?
    var onToggleTreo: (() -> Void)?

    private let iconImageView = UIImageView()
    private let badgeLabel = UILabel()
    private var isDragging = false

    private init() {
        let size: CGFloat = 60
        super.init(frame: CGRect(x: UIScreen.main.bounds.width - size - 12, y: 220, width: size, height: size))
        setupUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.92)
        layer.cornerRadius = 30
        layer.borderWidth = 2.5
        layer.borderColor = UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 0.95).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        clipsToBounds = false

        iconImageView.image = UIImage(named: "DecadeLogo") ?? UIImage(systemName: "gamecontroller.fill")
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 24
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        badgeLabel.text = "1"
        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor(red: 0.12, green: 0.45, blue: 0.90, alpha: 1.0)
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

    func setIcon(_ image: UIImage?) {
        if let img = image {
            iconImageView.image = img
        } else {
            iconImageView.image = UIImage(named: "DecadeLogo") ?? UIImage(systemName: "gamecontroller.fill")
        }
    }

    func setTabBadge(_ tabNumber: Int) {
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

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.alpha = 1.0
            self.transform = .identity
        }
    }

    func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in
            self.isHidden = true
            self.removeFromSuperview()
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let win = superview else { return }
        let translation = gesture.translation(in: win)

        switch gesture.state {
        case .began:
            isDragging = true
            UIView.animate(withDuration: 0.1) {
                self.alpha = 1.0
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        case .changed:
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: win)
        case .ended, .cancelled:
            isDragging = false
            snapToEdge(in: win)
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

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            self.center = CGPoint(x: targetX, y: targetY)
            self.transform = .identity
            self.alpha = 0.85
        }
    }

    @objc private func handleTap() {
        guard let rootVC = superview?.window?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController else {
            onRestoreGame?()
            return
        }

        let alert = UIAlertController(title: "Decade Assistive", message: "Bong bóng điều khiển nhanh", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "🎮 Mở lại màn hình game", style: .default) { [weak self] _ in
            self?.onRestoreGame?()
        })

        alert.addAction(UIAlertAction(title: "🌐 Gán proxy cho tab", style: .default) { [weak self] _ in
            self?.onAssignProxy?()
        })

        alert.addAction(UIAlertAction(title: "🌙 Treo tắt màn (Bật/Tắt)", style: .default) { [weak self] _ in
            self?.onToggleTreo?()
        })

        alert.addAction(UIAlertAction(title: "✕ Đóng bong bóng", style: .destructive) { [weak self] _ in
            self?.hide()
        })

        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds
        }

        rootVC.present(alert, animated: true)
    }
}
