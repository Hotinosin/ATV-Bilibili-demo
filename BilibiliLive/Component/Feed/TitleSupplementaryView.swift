//
//  TitleSupplementaryView.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/21.
//

import SnapKit
import UIKit

class TitleSupplementaryView: UICollectionReusableView {
    let label = UILabel()
    let separatorLine = UIView()
    static let reuseIdentifier = "title-supplementary-reuse-identifier"

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}

extension TitleSupplementaryView {
    func configure() {
        addSubview(label)
        addSubview(separatorLine)
        separatorLine.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        separatorLine.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview()
            make.bottom.equalToSuperview()
        }
        separatorLine.snp.makeConstraints { make in
            make.leading.equalTo(label.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .headline)
    }
}
