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

class MenusViewController: UIViewController, BLTabBarContentVCProtocol {
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

    @IBOutlet var menusView: UIView! {
        didSet {
            if #available(tvOS 26.0, *) {
                menusView.setGlassEffectView(style: .clear,
                                             cornerRadius: lessBigSornerRadius,
                                             tintColor: UIColor(named: "mainBgColor")?.withAlphaComponent(0.7))

            } else {
                menusView.setBlurEffectView(cornerRadius: lessBigSornerRadius)
                menusView.setCornerRadius(cornerRadius: lessBigSornerRadius, borderColor: .lightGray, borderWidth: 0.5)
            }
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

    @IBOutlet var menuViewWidth: NSLayoutConstraint!

    var focusableView = true

    var userName = ""

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
        leftCollectionView.register(BLMenuLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
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
        BLAfter(afterTime: 2) {
            self.view.addSubview(self.menusView)
            self.hiddenMenus(isHiddenSubView: true)

            self.menusView.snp.makeConstraints { make in
                make.top.left.equalTo(30)
            }
            BLAfter(afterTime: 1) {
                BLAnimate(withDuration: 0.4) {
                    self.menusView.alpha = 1
                    self.homeIcon.alpha = 1
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc func handleMenuPress() {
        NotificationCenter.default.post(name: EVENT_COLLECTION_TO_TOP, object: nil)
    }

    @objc func handleRightPress() {
        hiddenMenus()
    }
    func showMenus() {
        guard !menuIsShowing else { return }

        BLAfter(afterTime: 0.1) {
            self.view.setNeedsFocusUpdate()
            self.view.updateFocusIfNeeded()

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
                    self.menuViewWidth.constant = 320
                    self.menusView.setCornerRadius(cornerRadius: bigSornerRadius)

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
                }
            }
        }
    }
    
    func hiddenMenus(isHiddenSubView: Bool = false) {
        UIView.animate(withDuration: 0.4,
                  delay: 0,
                  usingSpringWithDamping: 0.85,
                  initialSpringVelocity: 0.5) {
            self.leftCollectionView.alpha = 0
            self.homeIcon.alpha = isHiddenSubView ? 0 : 1

            // 缩回布局
            self.collectionTop.constant = 0
            self.menusViewHeight.constant = 60
            self.headViewLeading.constant = 5
            self.headingViewTop.constant = 5
            self.menuViewWidth.constant = 180
            self.menusView.setCornerRadius(cornerRadius: 30)

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

            if let recognizer = self.menuRecognizer {
                self.view.addGestureRecognizer(recognizer)
            }
        }
    }

    override var preferredFocusedView: UIView? {
        return leftCollectionView
    }

    func setupData() {
        let lastLeft: () -> Void = { [weak self] in
            self?.showMenus()
        }
        let followsViewController = FollowsViewController()
        followsViewController.didSelectToLastLeft = lastLeft
        followsViewController.isShowTopCover = {
            false
        }
        followsViewController.isNeedFocusToMenu = {
            true
        }
        cellModels.append(CellModel(iconImage: UIImage(systemName: "person.crop.circle.badge.checkmark"), title: "关注", contentVC: followsViewController))

        let FeedViewController = FeedViewController()
        FeedViewController.isNeedFocusToMenu = {
            true
        }
        FeedViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "timelapse"), title: "推荐", contentVC: FeedViewController))

        let tvRecommendViewController = TVRecommendViewController()
        tvRecommendViewController.isNeedFocusToMenu = { true }
        tvRecommendViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "tv"), title: "TV推荐", contentVC: tvRecommendViewController))

        let historyViewController = HistoryViewController()
        historyViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "clock.fill"), title: "历史记录", contentVC: historyViewController))

        let HotViewController = HotViewController()
        HotViewController.isNeedFocusToMenu = {
            true
        }
        HotViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "livephoto.play"), title: "热门", contentVC: HotViewController))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "theatermasks.circle"), title: "排行榜", contentVC: RankingViewController()))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "infinity.circle"), title: "直播", contentVC: LiveViewController()))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "star.circle"), title: "收藏", contentVC: FavoriteViewController()))

        let logout = CellModel(iconImage: UIImage(systemName: "magnifyingglass.circle"), title: "搜索", autoSelect: false) {
            [weak self] in
//            self?.actionLogout()
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }
        cellModels.append(logout)
        cellModels.append(CellModel(iconImage: UIImage(systemName: "gear"), title: "设置", contentVC: PersonalViewController.create()))
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

        BLAfter(afterTime: 0.3) {
            self.hiddenMenus(isHiddenSubView: true)
        }
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) {
            _ in
            ApiRequest.logout { _ in
                WebRequest.logout {
                    AppDelegate.shared.showLogin()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
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
            cell.iconImageView.image = icon
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension MenusViewController: UICollectionViewDelegate {
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
            hiddenMenus()
            return
        }
    }
}
