//
//  SegmentViewController.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/29.
//

import Foundation
import SnapKit
import UIKit

class SegmentViewController: UIViewController, BLTabBarContentVCProtocol {
    static let contentTopInset: CGFloat = 64
    struct CategoryDisplayModel {
        let title: String
        let contentVC: UIViewController
        var autoSelect: Bool? = true
    }

    var segmentedControl: UISegmentedControl!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        segmentedControl == nil ? super.preferredFocusEnvironments : [segmentedControl]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if categories.isEmpty {
        } else {
            initSegmentedControl()
        }
    }

    func initSegmentedControl() {
        if segmentedControl != nil {
            return
        }

        let items = categories.map { $0.title }
        segmentedControl = UISegmentedControl(items: items)
        segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 24, weight: .bold)], for: .normal)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)

        view.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().inset(40)
            make.height.equalTo(64)
        }

        let leftFocusGuide = UIFocusGuide()
        view.addLayoutGuide(leftFocusGuide)
        leftFocusGuide.snp.makeConstraints { make in
            make.top.bottom.equalTo(segmentedControl)
            make.right.equalTo(segmentedControl.snp.left)
            make.left.equalToSuperview()
        }
        leftFocusGuide.preferredFocusEnvironments = [segmentedControl]

        let rightFocusGuide = UIFocusGuide()
        view.addLayoutGuide(rightFocusGuide)
        rightFocusGuide.snp.makeConstraints { make in
            make.top.bottom.equalTo(segmentedControl)
            make.left.equalTo(segmentedControl.snp.right)
            make.right.equalToSuperview()
        }
        rightFocusGuide.preferredFocusEnvironments = [segmentedControl]

        view.insertSubview(contentView, belowSubview: segmentedControl)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Load initial view controller
        if !categories.isEmpty {
            setViewController(vc: categories[0].contentVC)
        }
    }

    @objc func segmentChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        if index >= 0 && index < categories.count {
            setViewController(vc: categories[index].contentVC, animated: true)
        }
    }

    func setViewController(vc: UIViewController, animated: Bool = false) {
        guard currentViewController !== vc else { return }
        let install = {
            self.currentViewController?.willMove(toParent: nil)
            self.currentViewController?.view.removeFromSuperview()
            self.currentViewController?.removeFromParent()
            self.currentViewController = vc
            self.addChild(vc)
            self.contentView.addSubview(vc.view)
            vc.view.makeConstraintsToBindToSuperview()
            vc.didMove(toParent: self)
        }
        if animated, !UIAccessibility.isReduceMotionEnabled, view.window != nil {
            UIView.transition(with: contentView, duration: 0.25, options: .transitionCrossDissolve,
                              animations: install)
        } else {
            install()
        }
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}
