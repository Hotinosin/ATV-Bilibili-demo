//
//  BLTextOnlyCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/24.
//

import Foundation
import UIKit

class BLTextOnlyCollectionViewCell: BLMotionCollectionViewCell {
    private let effectView = UIVisualEffectView()
    private let selectedWhiteView = UIView()
    let titleLabel = UILabel()
    var didSelect: ((_ isFocused: Bool) -> Void)?

    override func setup() {
        super.setup()
        scaleFactor = standardFocusScale
        if #available(tvOS 26.0, *) {
            effectView.effect = UIGlassEffect(style: .clear)
        } else {
            effectView.effect = UIBlurEffect(style: .dark)
        }
        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.contentView.addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectedWhiteView.isHidden = true
        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.bottom.lessThanOrEqualToSuperview().inset(8)
        }
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        effectView.layer.cornerRadius = normailSornerRadius
        effectView.clipsToBounds = true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        didSelect?(isFocused)
        selectedWhiteView.isHidden = !isFocused
        selectedWhiteView.backgroundColor = UIColor.white.withAlphaComponent(0.18)
    }
}
