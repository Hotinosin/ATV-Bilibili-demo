//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import UIKit

class ReplyCell: UICollectionViewCell {
    class var identifier: String {
        return String(describing: Self.self)
    }

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!
    private var reply: Replys.Reply?
    private var baseAttributedText: NSAttributedString?

    func config(replay: Replys.Reply) {
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
