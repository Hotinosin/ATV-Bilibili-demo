//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import SnapKit
import SwiftUI
import TVUIKit
import UIKit

let sornerRadius = 8.0
let littleSornerRadius = 24.0
let moreLittleSornerRadius = 18.0
let normailSornerRadius = 25.0
let lessBigSornerRadius = 35.0
let bigSornerRadius = 45.0

let EVENT_COLLECTION_TO_TOP = NSNotification.Name("EVENT_COLLECTION_TO_TOP")
let EVENT_COLLECTION_TO_SHOW_MENU = NSNotification.Name("EVENT_COLLECTION_TO_SHOW_MENU")

protocol DisplayData: Hashable {
    var title: String { get }
    var ownerName: String { get }
    var pic: URL? { get }
    var avatar: URL? { get }
    var date: String? { get }
    var overlay: DisplayOverlay? { get }
}

extension DisplayData {
    var avatar: URL? { return nil }
    var date: String? { return nil }
    var overlay: DisplayOverlay? { return nil }
}

struct DisplayOverlay {
    var leftItems: [DisplayOverlayItem]
    var rightItems: [DisplayOverlayItem]
    var badge: DisplayOverlayBadge?

    init(leftItems: [DisplayOverlayItem], rightItems: [DisplayOverlayItem] = [], badge: DisplayOverlayBadge? = nil) {
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.badge = badge
    }

    struct DisplayOverlayItem {
        var icon: String?
        var text: String
    }

    struct DisplayOverlayBadge {
        var color: UIColor?
        var text: String
    }
}

struct FeedHeaderConfig {
    let elementKind: String
    let estimatedHeight: CGFloat
    let viewProvider: (UICollectionView, String, IndexPath) -> UICollectionReusableView?

    init<T: UICollectionReusableView>(
        viewType: T.Type,
        estimatedHeight: CGFloat = 44,
        configure: @escaping (T, IndexPath) -> Void
    ) {
        elementKind = String(describing: viewType)
        self.estimatedHeight = estimatedHeight

        let registration = UICollectionView.SupplementaryRegistration<T>(elementKind: elementKind) { view, _, indexPath in
            configure(view, indexPath)
        }

        viewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
        }
    }
}

struct AnyDispplayData: Hashable {
    let data: any DisplayData

    static func == (lhs: AnyDispplayData, rhs: AnyDispplayData) -> Bool {
        func eq<T: Equatable>(lhs: T, rhs: any Equatable) -> Bool {
            lhs == rhs as? T
        }
        return eq(lhs: lhs.data, rhs: rhs.data)
    }

    func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
}

class FeedCollectionViewController: UIViewController {
    var collectionView: UICollectionView!

    private enum Section: CaseIterable {
        case main
    }

    private var coverViewIsShowing = false

    var styleOverride: FeedDisplayStyle?
    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
    var showHeader: Bool = true
    var headerText = ""
    var customHeaderConfig: FeedHeaderConfig?
    var coverViewHeight = 500.0
    let collectionEdgeInsetTop = 40.0
    var isShowCove = false

    var nextFocusedIndexPath: IndexPath?

    let bgImageView = UIImageView()

    var backMenuAction: (() -> Void)?
    var didUpdateFocus: (() -> Void)?
    var isShowTopCover: (() -> Bool)?
    var isToToped: ((_ isTop: Bool) -> Void)?

    var didSelectToLastLeft: (() -> Void)?
    private var beforeSeleteIndex: IndexPath?

    private let viewModel = BannerViewModel()
    private var bannerSwiftUIView: BannerView?
    private var bannerUIView: UIView?
    private let animationOffSet = -200.0
    private let animateTime = 0.8

    var displayDatas: [any DisplayData] {
        set {
            _displayData = newValue.map { AnyDispplayData(data: $0) }.uniqued()
            finished = false
        }
        get {
            _displayData.map { $0.data }
        }
    }

    private var _displayData = [AnyDispplayData]() {
        didSet {
            var snapshot = NSDiffableDataSourceSnapshot<Section, AnyDispplayData>()
            snapshot.appendSections(Section.allCases)
            snapshot.appendItems(_displayData, toSection: .main)
            dataSource.apply(snapshot)
        }
    }

    private var isLoading = false

    typealias DisplayCellRegistration = UICollectionView.CellRegistration<FeedCollectionViewCell, AnyDispplayData>
    private lazy var dataSource = makeDataSource()

    // MARK: - Public

    deinit {
        print("🧹 FeedCollectionViewController deinitialized")
    }
    
    func show(in vc: UIViewController) {
        vc.addChild(self)
        vc.view.addSubview(view)
        view.makeConstraintsToBindToSuperview()
        didMove(toParent: vc)
        vc.setContentScrollView(collectionView)
    }

    func appendData(displayData: [any DisplayData]) {
        isLoading = false
        _displayData.append(contentsOf: displayData.map { AnyDispplayData(data: $0) }.filter({ !_displayData.contains($0) }))
        if displayData.count < pageSize - 5 || displayData.count == 0 {
            finished = true
            return
        }

        if _displayData.count < 12 {
            isLoading = true
            loadMore?()
        }
    }

    func reloadData() {
        Task {
            try await viewModel.loadFavList()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        背景图
        view.addSubview(bgImageView)
        bgImageView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(-60)
        }
        bgImageView.setBlurEffectView()

        if isShowTopCover?() ?? false {
            // 顶部大图
            let bannerSwiftUIView = BannerView(viewModel: viewModel)
            self.bannerSwiftUIView = bannerSwiftUIView
            viewModel.focusedBannerButton = { [weak self] in
                guard let self = self else { return }
                resetTopView()
            }

            viewModel.overMoveLeft = { [weak self] in
                guard let self = self else { return }
                didSelectToLastLeft?()
            }

            viewModel.playAction = { [weak self] data in
                guard let self = self else { return }
                let player = VideoPlayerViewController(playInfo: PlayInfo(aid: data.id, cid: data.cid, epid: 0))
                self.present(player, animated: true)
            }

            viewModel.detailAction = { [weak self] data in
                guard let self = self else { return }
                let detailVC = VideoDetailViewController.create(aid: data.id, cid: data.cid)
                detailVC.present(from: self)
            }
            // 创建 UIHostingController
            let hostingController = UIHostingController(rootView: bannerSwiftUIView)
            // 获取 hostingController 的 view
            bannerUIView = hostingController.view
            bannerUIView?.translatesAutoresizingMaskIntoConstraints = false

            if let bannerUIView = bannerUIView {
                view.addSubview(bannerUIView)
                bannerUIView.snp.makeConstraints { make in
                    make.left.right.equalToSuperview()
                    make.top.equalToSuperview()
                    make.height.equalTo(1080)
                }
            }

            // 内容
            collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
            view.addSubview(collectionView)
            collectionView.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.top.equalTo(bannerUIView!.snp.bottom).offset(animationOffSet)
                make.height.equalTo(1120)
            }
            collectionView.contentInset = UIEdgeInsets(top: collectionEdgeInsetTop, left: 0, bottom: 0, right: 0)

            Task {
                try await viewModel.loadFavList()
            }

        } else {
            // 内容
            collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
            view.addSubview(collectionView)
            collectionView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            collectionView.contentInset = UIEdgeInsets(top: collectionEdgeInsetTop, left: 0, bottom: 0, right: 0)
        }

        collectionView.dataSource = dataSource
        collectionView.delegate = self

        NotificationCenter.default.addObserver(forName: EVENT_COLLECTION_TO_TOP, object: nil, queue: .main) { [weak self] _ in
            self?.handleMenuPress()
        }
    }

    func handleMenuPress() {
        if collectionView.contentOffset.y > 100 {
            scrollPositionToTop()
        } else if collectionView.contentOffset.y == -collectionEdgeInsetTop
            && isShowTopCover?() ?? false
            && viewModel.offsetY != 0 {
            resetTopView()
        } else {
            NotificationCenter.default.post(name: EVENT_COLLECTION_TO_SHOW_MENU, object: nil)
        }
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            self?.makeGridLayoutSection()
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let style = styleOverride ?? Settings.displayStyle

        // top
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),

            heightDimension: .fractionalHeight(1)

        ))
        let hSpacing = style.hSpacing
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(style.groupFractionalHeight)
        ), repeatingSubitem: item, count: style.feedColCount)

        let vSpacing: CGFloat = style == .large ? 34 : 26
        let baseSpacing: CGFloat = style == .sideBar ? 34 : 0

        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))

        // section
        let section = NSCollectionLayoutSection(group: group)
        if baseSpacing > 0 {
            section.contentInsets = NSDirectionalEdgeInsets(top: baseSpacing, leading: 0, bottom: 0, trailing: 0)
        }

        if showHeader {
            let headerHeight = customHeaderConfig?.estimatedHeight ?? 44
            let headerKind = customHeaderConfig?.elementKind ?? TitleSupplementaryView.reuseIdentifier
            let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .estimated(headerHeight))
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: headerKind,
                alignment: .top
            )
            section.boundarySupplementaryItems = [titleSupplementary]
        }

        return section
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AnyDispplayData> {
        let dataSource = UICollectionViewDiffableDataSource<Section, AnyDispplayData>(collectionView: collectionView, cellProvider: makeCellRegistration().cellProvider)

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: TitleSupplementaryView.reuseIdentifier) {
            [weak self] supplementaryView, _, _ in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }
            if let customConfig = self.customHeaderConfig, kind == customConfig.elementKind {
                return customConfig.viewProvider(collectionView, kind, indexPath)
            }
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: indexPath
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, index, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data, indexPath: index)
            cell.onLongPress = { [weak self] in
                self?.didLongPress?(displayData.data)
            }
        }
    }

    func scrollPositionToTop() {
        let indexPath = IndexPath(item: 0, section: 0)
//            collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
//            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionEdgeInsetTop), animated: true)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
        collectionView.reloadData()
    }
}

extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            didSelect?(data.data)
        }
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        if let data = dataSource.itemIdentifier(for: indexPath), bgImageView.image == nil {
            bgImageView.kf.setImage(with: data.data.pic, placeholder: nil, options: nil) { _ in
            }
        }

        return indexPath
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }
        if let data = dataSource.itemIdentifier(for: indexPath), bgImageView.image == nil {
            bgImageView.kf.setImage(with: data.data.pic, placeholder: nil, options: nil) { _ in
            }
        }
        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        collectionView.visibleCells.compactMap { $0 as? BLMotionCollectionViewCell }.forEach { cell in
            cell.updateTransform()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        print("didUpdateFocusIn")

        if let indexPath = context.nextFocusedIndexPath {
            if let indexPath = nextFocusedIndexPath {
                let cell = collectionView.cellForItem(at: indexPath)
                if let cell = cell as? FeedCollectionViewCell {
//                    cell.infoView.isHidden = true
                    cell.infoView.alpha = 0.7
                }
            }

            let cell = collectionView.cellForItem(at: indexPath)
            if let cell = cell as? FeedCollectionViewCell {
//                cell.infoView.isHidden = false
                cell.infoView.alpha = 1
            }

            if isShowTopCover?() ?? false {
                // 当前 item 是最左边？
                let style = styleOverride ?? Settings.displayStyle
                if (indexPath.row + 1) > style.feedColCount {
                    // 第二行把上面的全部隐藏
                    UIView.animate(springDuration: animateTime, bounce: 0.1) {
                        bannerUIView?.snp.updateConstraints { make in
                            make.top.equalToSuperview().offset(-1110)
                        }

                        collectionView.snp.updateConstraints { make in
                            make.top.equalTo(bannerUIView!.snp.bottom).offset(-10)
                        }
                        view.layoutIfNeeded()
                    }

                    isToToped?(false)
                } else {
                    // 第一行
                    BLAfter(afterTime: 0.0) {
                        self.viewModel.offsetY = 130
                        UIView.animate(springDuration: self.animateTime, bounce: 0.1) {
                            self.bannerUIView?.snp.updateConstraints { make in
                                make.top.equalToSuperview().offset(-820)
                            }
                            collectionView.snp.updateConstraints { make in
                                if let bannerUIView = self.bannerUIView {
                                    make.top.equalTo(bannerUIView.snp.bottom).offset(0)
                                }
                            }
                            self.view.layoutIfNeeded()
                        }
                    }
                    isToToped?(false)
                }
            }

            // 焦点在第二行
            nextFocusedIndexPath = indexPath
  
        }
    }

    func resetTopView() {
        if bannerUIView?.superview != nil {
            UIView.animate(springDuration: animateTime, bounce: 0.1) {
                self.bannerUIView?.snp.updateConstraints { make in
                    make.top.equalToSuperview()
                }
                self.collectionView.snp.updateConstraints { make in
                    make.top.equalTo(self.bannerUIView!.snp.bottom).offset(self.animationOffSet)
                }
                self.view.layoutIfNeeded()
            }
        }
        viewModel.offsetY = 0
        isToToped?(true)
    }
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .big: return bigItmeCount
        case .normal: return normalItmeCount
        case .large, .sideBar: return largeItmeCount
        }
    }
}
