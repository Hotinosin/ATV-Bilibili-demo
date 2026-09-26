//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import TVUIKit
import UIKit

final class ReplyCardView: TVCardView {
    override var canBecomeFocused: Bool { false }
}

class ReplyCell: BLMotionCollectionViewCell {
    class var identifier: String {
        return String(describing: Self.self)
    }

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var cardView: ReplyCardView?
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!
    private var reply: Replys.Reply?
    private var baseAttributedText: NSAttributedString?

    func config(replay: Replys.Reply) {
        scaleFactor = 1.04
        reply = replay
        avatarImageView.kf.setImage(
            with: URL(string: replay.member.avatar),
            options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))),
                .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))),
                .cacheSerializer(FormatIndicatedCacheSerializer.png),
            ]
        )
        userNameLabel.text = replay.member.uname
        contenLabel.textAlignment = .left
        baseAttributedText = replay.createAttributedString(displayView: contenLabel)
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateAppearance()
    }

    private func updateAppearance() {
        guard let reply else { return }
        let color: UIColor = isFocused ? .black : .white
        cardView?.cardBackgroundColor = isFocused ? .white : UIColor.white.withAlphaComponent(0.12)
        userNameLabel.textColor = color
        if let attributedText = baseAttributedText?.mutableCopy() as? NSMutableAttributedString {
            attributedText.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attributedText.length))
            contenLabel.attributedText = attributedText
        } else {
            contenLabel.attributedText = nil
            contenLabel.text = reply.content.message
            contenLabel.textColor = color
        }
    }
}

final class CompactReplyCell: BLMotionCollectionViewCell {
    static let identifier = String(describing: CompactReplyCell.self)

    private let cardView = UIVisualEffectView()
    private let avatarImageView = UIImageView()
    private let commentLabel = UILabel()
    private var baseAttributedText: NSAttributedString?
    private var glassEffect: UIVisualEffect?

    override func setup() {
        super.setup()
        scaleFactor = 1.03
        if #available(tvOS 26.0, *) {
            glassEffect = UIGlassEffect(style: .clear)
        } else {
            glassEffect = UIBlurEffect(style: .dark)
        }
        cardView.effect = glassEffect
        cardView.layer.cornerRadius = normailSornerRadius
        cardView.layer.borderWidth = 1
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.contentView.addSubview(avatarImageView)
        cardView.contentView.addSubview(commentLabel)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        commentLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            avatarImageView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 20),
            avatarImageView.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),
            commentLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 16),
            commentLabel.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            commentLabel.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 12),
            commentLabel.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -12),
        ])
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 26
        avatarImageView.clipsToBounds = true
        commentLabel.numberOfLines = 3
        commentLabel.textAlignment = .left
        commentLabel.font = .systemFont(ofSize: 24)
        updateAppearance()
    }

    func config(replay: Replys.Reply) {
        avatarImageView.kf.setImage(
            with: URL(string: replay.member.avatar),
            options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 52, height: 52)))]
        )
        let text = NSMutableAttributedString(string: "\(replay.member.uname)  ", attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .semibold)])
        text.append(replay.createAttributedString(displayView: commentLabel) ?? NSAttributedString(string: replay.content.message))
        baseAttributedText = text
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }

    private func updateAppearance() {
        let color: UIColor = isFocused ? .black : .white
        cardView.effect = isFocused ? nil : glassEffect
        cardView.backgroundColor = isFocused ? .white : .clear
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(isFocused ? 0 : 0.18).cgColor
        let text = NSMutableAttributedString(attributedString: baseAttributedText ?? NSAttributedString())
        text.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: text.length))
        commentLabel.attributedText = text
    }
}
