//
//  BLSettingLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import UIKit

class BLSettingLineCollectionViewCell: BLMotionCollectionViewCell {
    let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    let selectedWhiteView = UIView()
    let titleLabel = UILabel()
    override var isSelected: Bool {
        didSet {
            updateView()
        }
    }

    override func setup() {
        super.setup()
        scaleFactor = 1.05

        addsubViews()
    }

    func addsubViews() {
        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.layer.cornerRadius = moreLittleSornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        selectedWhiteView.backgroundColor = UIColor.white
        selectedWhiteView.isHidden = !isFocused
        effectView.contentView.addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(26)
            make.trailing.equalToSuperview().offset(26)
            make.top.bottom.equalToSuperview().inset(8)
        }
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        titleLabel.textColor = .black
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateView()
    }

    func updateView() {
        selectedWhiteView.isHidden = !(isFocused || isSelected)
    }

    static func makeLayout() -> UICollectionViewCompositionalLayout {
        // 每个 item 的尺寸（宽度占容器的 90%，高度占满 group）
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.85),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // 每个 group 的尺寸（宽度占满容器，高度固定 70pt）
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(70)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        // 创建 section
        let section = NSCollectionLayoutSection(group: group)

        // 🔹 垂直滚动方向
        section.orthogonalScrollingBehavior = .none

        // 🔹 cell 垂直方向间距
        section.interGroupSpacing = 12

        // 🔹 内容内边距：上下间距 + 左右留白（居中效果）
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 20, leading: 0, bottom: 20, trailing: 0
        )
        // ✅ 最终布局对象
        return UICollectionViewCompositionalLayout(section: section)
    }
}
