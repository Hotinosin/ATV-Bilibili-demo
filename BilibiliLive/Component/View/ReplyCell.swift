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
        scaleFactor = compactFocusScale
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
    var showsFullText = false {
        didSet {
            commentLabel.numberOfLines = showsFullText ? 0 : 1
            avatarWidthConstraint?.constant = showsFullText ? 52 : 40
            avatarHeightConstraint?.constant = showsFullText ? 52 : 40
            avatarImageView.layer.cornerRadius = showsFullText ? 26 : 20
            statsWidthConstraint?.constant = showsFullText ? 420 : 220
            updateAppearance()
        }
    }

    private let cardView = UIVisualEffectView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let commentLabel = UILabel()
    private let statsLabel = UILabel()
    private var avatarWidthConstraint: NSLayoutConstraint?
    private var avatarHeightConstraint: NSLayoutConstraint?
    private var statsWidthConstraint: NSLayoutConstraint?
    private var baseAttributedText: NSAttributedString?
    private var glassEffect: UIVisualEffect?
    private var likeCount = 0
    private var replyCount = 0
    private var timestamp: String?

    override func setup() {
        super.setup()
        scaleFactor = prominentFocusScale
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
        cardView.contentView.addSubview(nameLabel)
        cardView.contentView.addSubview(commentLabel)
        cardView.contentView.addSubview(statsLabel)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        commentLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        let avatarWidthConstraint = avatarImageView.widthAnchor.constraint(equalToConstant: 40)
        let avatarHeightConstraint = avatarImageView.heightAnchor.constraint(equalToConstant: 40)
        self.avatarWidthConstraint = avatarWidthConstraint
        self.avatarHeightConstraint = avatarHeightConstraint
        let statsWidthConstraint = statsLabel.widthAnchor.constraint(equalToConstant: 220)
        self.statsWidthConstraint = statsWidthConstraint
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            avatarImageView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 20),
            avatarImageView.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            avatarWidthConstraint,
            avatarHeightConstraint,
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 210),
            commentLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 28),
            commentLabel.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            commentLabel.trailingAnchor.constraint(lessThanOrEqualTo: statsLabel.leadingAnchor, constant: -24),
            statsLabel.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            statsLabel.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            statsWidthConstraint,
        ])
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.clipsToBounds = true
        nameLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        commentLabel.numberOfLines = 1
        commentLabel.lineBreakMode = .byTruncatingTail
        commentLabel.textAlignment = .left
        commentLabel.font = .systemFont(ofSize: 24)
        statsLabel.font = .systemFont(ofSize: 19)
        statsLabel.textAlignment = .right
        updateAppearance()
    }

    func config(replay: Replys.Reply, replyTarget: String? = nil) {
        avatarImageView.kf.setImage(
            with: URL(string: replay.member.avatar),
            options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 52, height: 52)))]
        )
        nameLabel.text = replay.member.uname
        let text = NSMutableAttributedString()
        if let replyTarget {
            text.append(NSAttributedString(string: "回复 @\(replyTarget)：", attributes: [.font: UIFont.systemFont(ofSize: 23, weight: .medium)]))
        }
        text.append(replay.createAttributedString(displayView: commentLabel) ?? NSAttributedString(string: replay.content.message))
        baseAttributedText = text
        likeCount = replay.like ?? 0
        replyCount = replay.rcount ?? 0
        timestamp = DateFormatter.stringFor(timestamp: replay.ctime)
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }

    private func updateAppearance() {
        let color: UIColor = .white
        cardView.effect = glassEffect
        cardView.backgroundColor = isFocused ? UIColor.white.withAlphaComponent(0.18) : .clear
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(isFocused ? 0 : 0.18).cgColor
        let text = NSMutableAttributedString(attributedString: baseAttributedText ?? NSAttributedString())
        text.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: text.length))
        nameLabel.textColor = color
        commentLabel.attributedText = text
        let metricColor = color.withAlphaComponent(isFocused ? 0.7 : 0.75)
        let stats = NSMutableAttributedString()
        if showsFullText, let timestamp {
            stats.append(NSAttributedString(string: "\(timestamp)   ", attributes: [.foregroundColor: metricColor]))
        }
        for (symbol, count) in [("hand.thumbsup", likeCount), ("bubble.right", replyCount)] {
            let icon = NSTextAttachment()
            icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19))?
                .withTintColor(metricColor, renderingMode: .alwaysOriginal)
            icon.bounds = CGRect(x: 0, y: -3, width: 21, height: 21)
            stats.append(NSAttributedString(attachment: icon))
            stats.append(NSAttributedString(string: " \(count)   ", attributes: [.foregroundColor: metricColor]))
        }
        statsLabel.attributedText = stats
    }
}
