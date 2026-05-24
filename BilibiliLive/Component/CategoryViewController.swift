//
//  CategoryViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/2/26.
//

import Foundation
import UIKit

class CategoryViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CategoryDisplayModel {
        let title: String
        let contentVC: UIViewController
        var autoSelect: Bool? = true
    }

    var typeCollectionView: UICollectionView!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        if categories.isEmpty {
        } else {
            initTypeCollectionView()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func initTypeCollectionView() {
        if typeCollectionView != nil {
            return
        }

        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.bottom.right.left.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }

        typeCollectionView = UICollectionView(frame: .zero, collectionViewLayout: BLSettingLineCollectionViewCell.makeLayout())
        typeCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        view.addSubview(typeCollectionView)
        typeCollectionView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(40)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-40)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(80)
            make.width.equalTo(300)
        }
        typeCollectionView.dataSource = self
        typeCollectionView.delegate = self
        typeCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(typeCollectionView, didSelectItemAt: IndexPath(item: 0, section: 0))

        let backgroundView = UIView()
        backgroundView.setAutoGlassEffectView(cornerRadius: bigSornerRadius)
        view.insertSubview(backgroundView, at: 1)
        backgroundView.snp.makeConstraints { make in
            make.left.right.equalTo(typeCollectionView)
            make.top.equalTo(typeCollectionView).offset(-20)
            make.bottom.equalTo(typeCollectionView).offset(20)
        }
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}

extension CategoryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = categories[indexPath.item].title

        cell.didUpdateFocus = { [weak self] isFocused in
            self?.isShowMenus(isFocused: isFocused)
        }
        return cell
    }

    func isShowMenus(isFocused: Bool) {
        UIView.animate(springDuration: 0.4, bounce: 0.2) {
            if isFocused {
                self.typeCollectionView.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(40)
                }
            } else {
                self.typeCollectionView.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(-220)
                }
            }
            self.view.layoutIfNeeded()
        }
    }
}

extension CategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        isShowMenus(isFocused: false)
        setViewController(vc: categories[indexPath.item].contentVC)
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if Settings.sideMenuAutoSelectChange == false {
            return
        }
        guard let nextFocusedIndexPath = context.nextFocusedIndexPath else {
            return
        }
        let categoryModel = categories[nextFocusedIndexPath.item]
        if categoryModel.autoSelect == false {
            // 不自动选中
            return
        }
        collectionView.selectItem(at: nextFocusedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        setViewController(vc: categoryModel.contentVC)
    }
}
