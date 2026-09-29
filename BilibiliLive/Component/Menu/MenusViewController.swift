//
//  MenusViewController.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import Alamofire
import Kingfisher
import SwiftyJSON
import UIKit

private final class AccountHeaderControl: UIControl {
    weak var titleLabel: UILabel?
    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.backgroundColor = self.isFocused ? .white : .clear
            self.titleLabel?.textColor = self.isFocused ? .black : UIColor(named: "titleColor")
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.contains(where: { $0.type == .select }) {
            sendActions(for: .primaryActionTriggered)
        }
    }
}

class MenusViewController: UIViewController, BLTabBarContentVCProtocol {
    private enum FocusDestination {
        case menu
        case content
    }

    static func create() -> MenusViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! MenusViewController
    }

    @IBOutlet var contentView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel! {
        didSet {
            usernameLabel.text = "主页"
        }
    }

    @IBOutlet var leftCollectionView: BSCollectionVIew!
    weak var currentViewController: UIViewController?
    private var menuIsShowing = false
    private var menuRecognizer: UITapGestureRecognizer?
    private var selectMenuItem: CellModel?
    private let focusToMenuView = FocusToMenuView()
    private let accountButton = AccountHeaderControl()
    private var focusDestination = FocusDestination.menu

    @IBOutlet var menusView: UIView! {
        didSet {
            if #available(tvOS 26.0, *) {
                menusView.setGlassEffectView(style: .regular,
                                             cornerRadius: lessBigSornerRadius,
                                             tintColor: UIColor(named: "mainBgColor")?.withAlphaComponent(0.9))

            } else {
                menusView.setBlurEffectView(cornerRadius: lessBigSornerRadius)
                menusView.layer.borderColor = UIColor.lightGray.cgColor
                menusView.layer.borderWidth = 0.5
            }
            menusView.layer.shadowColor = UIColor.black.cgColor
            menusView.layer.shadowOffset = .zero
            updateMenuCornerRadius(lessBigSornerRadius)
            menusView.alpha = 0
            menusView.removeFromSuperview()
        }
    }

    @IBOutlet var homeIcon: UIImageView! {
        didSet {
            homeIcon.setImageColor(color: .gray)
            homeIcon.alpha = 0
        }
    }

    @IBOutlet var menusLeft: NSLayoutConstraint!
    @IBOutlet var menusViewHeight: NSLayoutConstraint!

    @IBOutlet var vcLeft: NSLayoutConstraint!
    @IBOutlet var collectionTop: NSLayoutConstraint!
    @IBOutlet var headViewLeading: NSLayoutConstraint!
    @IBOutlet var headingViewTop: NSLayoutConstraint!
    @IBOutlet var accountHeaderHeight: NSLayoutConstraint!
    @IBOutlet var avatarWidth: NSLayoutConstraint!

    @IBOutlet var menuViewWidth: NSLayoutConstraint!

    var focusableView = true

    var userName = ""

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        leftCollectionView.reloadData()
        leftCollectionView.register(BLMenuLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        accountButton.layer.cornerRadius = 26
        accountButton.isHidden = true
        accountButton.accessibilityLabel = "账号，退出登录"
        accountButton.titleLabel = usernameLabel
        accountButton.addTarget(self, action: #selector(actionLogout), for: .primaryActionTriggered)
        if let header = avatarImageView.superview {
            header.insertSubview(accountButton, at: 0)
            accountButton.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        contentView.addSubview(focusToMenuView)
        focusToMenuView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(33)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(1)
        }
        WebRequest.requestLoginInfo { [weak self] response in
            switch response {
            case let .success(json):
                self?.avatarImageView.kf.setImage(with: URL(string: json["face"].stringValue))
                self?.userName = json["uname"].stringValue
            case .failure:
                break
            }
        }
        menusLeft.constant = 40

        view.backgroundColor = UIColor(named: "mainBgColor")

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(forName: EVENT_COLLECTION_TO_SHOW_MENU, object: nil, queue: .main) { [weak self] _ in
            self?.showMenus()
        }

        menuRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMenuPress))
        menuRecognizer?.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuRecognizer!)
        view.addSubview(menusView)
        menusView.snp.makeConstraints { make in
            make.top.left.equalTo(30)
        }
        menusView.alpha = 1
        homeIcon.alpha = 1
        hiddenMenus()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
    }

    @objc func handleMenuPress() {
        NotificationCenter.default.post(name: EVENT_COLLECTION_TO_TOP, object: nil)
    }

    @objc func handleRightPress() {
        hiddenMenus(focusContent: true)
    }
    func showMenus() {
        guard !menuIsShowing else { return }
        focusDestination = .menu

        BLAfter(afterTime: 0.1) {
            // 先轻微预备动画（让 UI 有呼吸感）
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
                self.menusView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            } completion: { _ in
                UIView.animate(withDuration: 0.45,
                          delay: 0,
                          usingSpringWithDamping: 0.8,
                          initialSpringVelocity: 0.5) {
                    if let recognizer = self.menuRecognizer {
                        self.view.removeGestureRecognizer(recognizer)
                    }

                    // 渐变显示子元素
                    self.leftCollectionView.alpha = 1
                    self.homeIcon.alpha = 0

                    // 调整布局常量
                    self.collectionTop.constant = 40
                    self.menusViewHeight.constant = 1020
                    self.headViewLeading.constant = 20
                    self.headingViewTop.constant = 20
                    self.accountHeaderHeight.constant = 64
                    self.avatarWidth.constant = 60
                    self.usernameLabel.font = .systemFont(ofSize: 26, weight: .semibold)
                    self.menuViewWidth.constant = 320
                    self.updateMenuCornerRadius(bigSornerRadius)

                    // 阴影更柔和
                    self.menusView.layer.shadowOpacity = 0.3
                    self.menusView.layer.shadowRadius = 18
                    self.menusView.transform = .identity

                    // label 动画
                    UIView.transition(with: self.usernameLabel,
                                      duration: 0.3,
                                      options: [.transitionCrossDissolve]) {
                        self.usernameLabel.text = self.userName
                    }
                    self.usernameLabel.transform = CGAffineTransform(scaleX: 1.01, y: 1.01)
                    self.usernameLabel.alpha = 0.6
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    // 平滑过渡
                    BLAnimate(withDuration: 0.3) {
                        self.usernameLabel.transform = .identity
                        self.usernameLabel.alpha = 1
                    }
                    self.menuIsShowing = true
                    self.accountButton.isHidden = false
                    self.view.setNeedsFocusUpdate()
                    self.view.updateFocusIfNeeded()
                }
            }
        }
    }
    
    func hiddenMenus(isHiddenSubView: Bool = false, focusContent: Bool = false) {
        UIView.animate(withDuration: 0.4,
                  delay: 0,
                  usingSpringWithDamping: 0.85,
                  initialSpringVelocity: 0.5) {
            self.leftCollectionView.alpha = 0
            self.homeIcon.alpha = isHiddenSubView ? 0 : 1

            // 缩回布局
            self.collectionTop.constant = 0
            self.menusViewHeight.constant = 64
            self.headViewLeading.constant = 16
            self.headingViewTop.constant = 7
            self.accountHeaderHeight.constant = 50
            self.avatarWidth.constant = 50
            self.usernameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
            self.menuViewWidth.constant = 200
            self.updateMenuCornerRadius(30)

            // 模糊阴影逐渐减弱
            self.menusView.layer.shadowOpacity = 0.1
            self.menusView.layer.shadowRadius = 6

            // usernameLabel 动画
            UIView.transition(with: self.usernameLabel,
                              duration: 0.3,
                              options: [.transitionCrossDissolve]) {
                self.usernameLabel.text = self.selectMenuItem?.title
            }
            self.usernameLabel.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.usernameLabel.alpha = 0.8

            self.view.layoutIfNeeded()
        } completion: { _ in
            UIView.animate(withDuration: 0.25) {
                self.usernameLabel.transform = .identity
                self.usernameLabel.alpha = 1
            }
            self.menuIsShowing = false
            self.accountButton.isHidden = true

            if focusContent {
                self.focusDestination = .content
                self.contentView.bringSubviewToFront(self.focusToMenuView)
                self.view.setNeedsFocusUpdate()
                self.view.updateFocusIfNeeded()
            }

            if let recognizer = self.menuRecognizer {
                self.view.addGestureRecognizer(recognizer)
            }
        }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        switch focusDestination {
        case .menu:
            return [leftCollectionView]
        case .content:
            guard let currentViewController else { return [contentView] }
            let preferred = currentViewController.preferredFocusEnvironments
            return preferred.isEmpty ? [currentViewController.view] : preferred
        }
    }

    private func updateMenuCornerRadius(_ radius: CGFloat) {
        menusView.layer.cornerRadius = radius
        menusView.layer.masksToBounds = false
        if #available(tvOS 26.0, *) {
            menusView.subviews.compactMap { $0 as? UIVisualEffectView }.first?.cornerConfiguration = .corners(radius: .fixed(radius))
        }
    }

    func setupData() {
        let followsViewController = FollowsViewController()
        followsViewController.isShowTopCover = {
            false
        }
        let followingViewController = SegmentViewController()
        followingViewController.categories = [
            .init(title: "更新", contentVC: followsViewController),
            .init(title: "正在直播", contentVC: LiveViewController()),
            .init(title: "关注UP", contentVC: FollowUpsViewController()),
        ]

        let feedViewController = MobileRecommendViewController()
        feedViewController.collectionVC.showHeader = false
        let tvRecommendViewController = WebRecommendViewController()
        tvRecommendViewController.collectionVC.showHeader = false
        let recommendationViewController = SegmentViewController()
        recommendationViewController.categories = [
            .init(title: "网页端推荐", contentVC: tvRecommendViewController),
            .init(title: "移动端推荐", contentVC: feedViewController),
            .init(title: "沉浸推荐", contentVC: FeaturedBrowserViewController()),
        ]
        cellModels.append(CellModel(iconImage: UIImage(systemName: "timelapse"), title: "推荐", contentVC: recommendationViewController))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "person.crop.circle.badge.checkmark"), title: "关注", contentVC: followingViewController))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "play.tv"), title: "影视", contentVC: CinemaViewController()))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "star.circle"), title: "收藏", contentVC: FavoriteViewController()))

        let historyViewController = SegmentViewController()
        historyViewController.categories = [
            .init(title: "历史记录", contentVC: HistoryViewController()),
            .init(title: "稍后再看", contentVC: ToViewViewController()),
        ]
        cellModels.append(CellModel(iconImage: UIImage(systemName: "clock.fill"), title: "历史", contentVC: historyViewController))

        let search = CellModel(iconImage: UIImage(systemName: "magnifyingglass.circle"), title: "搜索", autoSelect: false) {
            [weak self] in
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }
        cellModels.append(search)

        let hotViewController = SegmentViewController()
        hotViewController.categories = [
            .init(title: "热门视频", contentVC: HotViewController()),
            .init(title: "每周必看", contentVC: WeeklyWatchViewController()),
        ]
        cellModels.append(CellModel(iconImage: UIImage(systemName: "livephoto.play"), title: "热门", contentVC: hotViewController))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "theatermasks.circle"), title: "排行榜", contentVC: RankingViewController()))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "gear"), title: "设置", contentVC: SettingsViewController()))
    }

    func setViewController(vc: UIViewController, isHiddenMenus: Bool = true) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
        contentView.bringSubviewToFront(focusToMenuView)

        BLAfter(afterTime: 0.3) {
            self.hiddenMenus(isHiddenSubView: true, focusContent: true)
        }
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    @objc func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) {
            _ in
            ApiRequest.logout { _ in
                WebRequest.logout {
                    AppDelegate.shared.showLogin()
                }
            }
        })
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancel)
        alert.preferredAction = cancel
        present(alert, animated: true)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        guard let buttonPress = presses.first?.type else { return }
        if buttonPress == .playPause {
            if let reloadVC = topMostViewController() as? BLTabBarContentVCProtocol {
                print("send reload to \(reloadVC)")
                reloadVC.reloadData()
            }
        }
    }
}

extension MenusViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLMenuLineCollectionViewCell
        cell.titleLabel.text = cellModels[indexPath.item].title
        if let icon = cellModels[indexPath.item].iconImage {
            cell.iconImageView.image = icon.withRenderingMode(.alwaysTemplate)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension MenusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool
    {
        let isLeavingMenu = context.previouslyFocusedIndexPath != nil && context.nextFocusedIndexPath == nil
        let movesToAccount = context.focusHeading.contains(.up) && context.nextFocusedView === accountButton
        if isLeavingMenu && !context.focusHeading.contains(.right) && !movesToAccount {
            return false
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = cellModels[indexPath.item]
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        selectMenuItem = model
        model.action?()
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 检查新的焦点是否是UICollectionViewCell，失去焦点后隐藏菜单
        guard context.nextFocusedIndexPath != nil else {
            if context.nextFocusedView !== accountButton {
                hiddenMenus()
            }
            return
        }
    }
}
