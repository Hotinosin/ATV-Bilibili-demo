//
//  BLMenuLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import UIKit

class BLMenuLineCollectionViewCell: BLSettingLineCollectionViewCell {
    var iconImageView = UIImageView()
    override func addsubViews() {
        
//        selectedWhiteView.setAutoGlassEffectView(cornerRadius: selectedWhiteView.height / 2)
        selectedWhiteView.setCornerRadius(cornerRadius: height / 2)
        selectedWhiteView.backgroundColor = UIColor(named: "menuCellColor")
        selectedWhiteView.isHidden = !isFocused
        addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectedWhiteView.alpha = 0.7
        addSubview(iconImageView)
        let imageViewHeight = 32.0
        iconImageView.setCornerRadius(cornerRadius: imageViewHeight / 2.0)
        iconImageView.contentMode = .scaleAspectFit
        
        iconImageView.setImageColor(color: UIColor(named: "titleColor"))
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(imageViewHeight)
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.trailing.equalToSuperview().offset(8)
            make.centerY.equalTo(iconImageView)
        }
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        titleLabel.textColor = UIColor(named: "titleColor")
    }
}
