//
//  FollowBangumiViewController.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/29.
//

import SnapKit
import UIKit

class FollowBangumiViewController: SegmentViewController {
    override func viewDidLoad() {
        categories = [
            CategoryDisplayModel(title: "番剧", contentVC: BangumiListViewController(type: 1)),
            CategoryDisplayModel(title: "影视", contentVC: BangumiListViewController(type: 2)),
        ]
        super.viewDidLoad()
    }
}

final class CinemaViewController: SegmentViewController {
    override func viewDidLoad() {
        categories = [
            CategoryDisplayModel(title: "已订阅", contentVC: SubscribedSeriesCategoriesViewController()),
            CategoryDisplayModel(title: "电影", contentVC: CinemaListViewController(type: 2)),
            CategoryDisplayModel(title: "电视剧", contentVC: CinemaListViewController(type: 5)),
            CategoryDisplayModel(title: "综艺", contentVC: CinemaListViewController(type: 7)),
            CategoryDisplayModel(title: "纪录片", contentVC: CinemaListViewController(type: 3)),
            CategoryDisplayModel(title: "番剧", contentVC: CinemaListViewController(type: 1)),
        ]
        super.viewDidLoad()
    }
}

private final class CinemaFilterHeaderView: UICollectionReusableView {}

final class CinemaListViewController: StandardVideoCollectionViewController<CinemaIndexItem> {
    let type: Int
    private let filterPanel = UIStackView()
    private var filterButtons: [String: [CinemaFilterOptionButton]] = [:]
    private var conditions: CinemaIndexConditions?
    private var filters: [String: String] = [:]
    private var order: String?

    init(type: Int) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        filterPanel.axis = .vertical
        filterPanel.alignment = .fill
        filterPanel.spacing = 8
        Task { [weak self] in
            guard let self else { return }
            self.conditions = try? await WebRequest.requestCinemaConditions(type: self.type)
            self.showInlineFilters()
        }
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 24
        collectionVC.showHeader = true
        collectionVC.customHeaderConfig = FeedHeaderConfig(viewType: CinemaFilterHeaderView.self, estimatedHeight: 180) { [weak self] header, _ in
            guard let self else { return }
            header.addSubview(self.filterPanel)
            self.filterPanel.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview().inset(16)
                make.leading.trailing.equalToSuperview().inset(100)
            }
        }
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 40, right: 0)
    }

    override func request(page: Int) async throws -> [CinemaIndexItem] {
        let selectedFilters = filters
        let selectedOrder = order
        let indexed = try await WebRequest.requestCinemaIndex(type: type, page: page, filters: selectedFilters, order: selectedOrder).list
        guard page == 1, selectedFilters.isEmpty, selectedOrder == nil, let featured = try? await WebRequest.requestCinemaFeatured(type: type) else {
            return indexed
        }
        let featuredIDs = Set(featured.map(\.season_id))
        return featured + indexed.filter { !featuredIDs.contains($0.season_id) }
    }

    private func showInlineFilters() {
        guard let conditions else { return }
        filterButtons.removeAll()
        filterPanel.arrangedSubviews.forEach {
            filterPanel.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let sortOptions = conditions.order.map { CinemaIndexConditions.Option(name: $0.name, keyword: $0.field) }
        filterPanel.addArrangedSubview(makeFilterGroup(title: "热播", field: "order", options: sortOptions))
        let fields = ["style_id", "area", "season_status"]
        let groups = fields.compactMap { field in conditions.filter.first { $0.field == field } }
        for group in groups.prefix(2) {
            filterPanel.addArrangedSubview(makeFilterGroup(title: group.field == "season_status" ? "分类" : group.name,
                                                           field: group.field, options: group.values))
        }
    }

    private func makeFilterGroup(title: String, field: String, options: [CinemaIndexConditions.Option]) -> UIView {
        let group = UIStackView()
        group.axis = .horizontal
        group.alignment = .center
        group.spacing = 16
        group.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 26, weight: .semibold)
        group.addArrangedSubview(label)
        label.snp.makeConstraints { make in
            make.width.equalTo(76)
        }
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        group.addArrangedSubview(scrollView)
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16
        scrollView.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
        for option in options where option.keyword != "-1" {
            let button = CinemaFilterOptionButton()
            button.keyword = option.keyword
            button.setTitle(option.name, for: .normal)
            button.isSelected = (field == "order" ? order : filters[field]) == option.keyword
            button.addAction(UIAction { [weak self] _ in
                self?.applyFilter(field: field, option: option)
            }, for: .primaryActionTriggered)
            row.addArrangedSubview(button)
            filterButtons[field, default: []].append(button)
        }
        if field == "order" {
            let reset = CinemaFilterOptionButton()
            reset.setTitle("全部重置", for: .normal)
            reset.addAction(UIAction { [weak self] _ in
                self?.order = nil
                self?.filters.removeAll()
                self?.updateFilterSelection()
                self?.reloadFilteredData()
            }, for: .primaryActionTriggered)
            group.addArrangedSubview(reset)
        }
        return group
    }

    private func applyFilter(field: String, option: CinemaIndexConditions.Option) {
        if field == "order" {
            order = option.keyword
        } else if option.keyword == "-1" {
            filters.removeValue(forKey: field)
        } else {
            filters[field] = option.keyword
        }
        updateFilterSelection()
        reloadFilteredData()
    }

    private func updateFilterSelection() {
        for (field, buttons) in filterButtons {
            let selectedKeyword = field == "order" ? order : filters[field]
            for button in buttons {
                button.isSelected = button.keyword == selectedKeyword
            }
        }
    }

    private func reloadFilteredData() {
        collectionVC.collectionView.setContentOffset(CGPoint(x: 0, y: -collectionVC.collectionView.contentInset.top), animated: false)
        reloadData()
    }

    override func goDetail(with record: CinemaIndexItem) {
        VideoDetailViewController.create(seasonId: record.season_id, coverURL: record.pic).present(from: self)
    }
}

private final class CinemaFilterOptionButton: UIButton {
    var keyword: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        updateAppearance()
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 24, height: max(size.height + 16, 44))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }

    private func updateAppearance() {
        setTitleColor(isFocused ? .black : (isSelected ? .white : UIColor.white.withAlphaComponent(0.75)), for: .normal)
        backgroundColor = isFocused ? .white : (isSelected ? UIColor.white.withAlphaComponent(0.25) : .clear)
        layer.cornerRadius = 22
    }
}

struct CinemaIndexItem: Codable, Hashable, PlayableData {
    let season_id: Int
    let title: String
    let cover: URL
    let index_show: String?

    init(season_id: Int, title: String, cover: URL, index_show: String?) {
        self.season_id = season_id
        self.title = title
        self.cover = cover
        self.index_show = index_show
    }

    var aid: Int { 0 }
    var cid: Int { 0 }
    var ownerName: String { index_show ?? "" }
    var pic: URL? { cover.addSchemeIfNeed() }
}

extension WebRequest {
    static func requestCinemaIndex(type: Int, page: Int, filters: [String: String] = [:], order: String? = nil) async throws -> CinemaIndexResponse {
        var parameters: [String: Any] = ["season_type": type, "st": type, "type": 1, "page": page, "pagesize": 24, "sort": 0]
        if let order { parameters["order"] = order }
        parameters.merge(filters) { _, new in new }
        return try await request(url: "https://api.bilibili.com/pgc/season/index/result",
                                 parameters: parameters)
    }

    static func requestCinemaConditions(type: Int) async throws -> CinemaIndexConditions {
        try await request(url: "https://api.bilibili.com/pgc/season/index/condition",
                          parameters: ["season_type": type, "type": 1])
    }

    static func requestCinemaFeatured(type: Int) async throws -> [CinemaIndexItem] {
        // ponytail: The public homepage JSON supplies editorial picks; fall back to the index if its markup changes.
        guard let path = [2: "movie", 7: "variety"][type],
              let url = URL(string: "https://www.bilibili.com/\(path)/") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8),
              let start = html.range(of: "window.__INITIAL_STATE__="),
              let end = html.range(of: ";(function", range: start.upperBound..<html.endIndex) else { return [] }
        let state = Data(html[start.upperBound..<end.lowerBound].utf8)
        guard let root = try JSONSerialization.jsonObject(with: state) as? [String: Any],
              let modules = root["modules"] as? [String: Any],
              let sections = modules["ext"] as? [[String: Any]],
              let featured = sections.first(where: { $0["style"] as? String == "web_hot_v2" }),
              let items = featured["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["season_id"] as? Int,
                  let title = item["title"] as? String,
                  let cover = item["cover"] as? String,
                  let url = URL(string: cover.hasPrefix("//") ? "https:\(cover)" : cover) else { return nil }
            return CinemaIndexItem(season_id: id, title: title, cover: url, index_show: item["sub_title"] as? String)
        }
    }
}

struct CinemaIndexConditions: Decodable {
    struct Option: Decodable {
        let name: String
        let keyword: String
    }

    struct Filter: Decodable {
        let name: String
        let field: String
        let values: [Option]
    }

    struct Order: Decodable {
        let name: String
        let field: String
    }

    let filter: [Filter]
    let order: [Order]
}

struct CinemaIndexResponse: Codable {
    let list: [CinemaIndexItem]
}

final class SubscribedSeriesCategoriesViewController: SegmentViewController {
    override func viewDidLoad() {
        categories = [
            CategoryDisplayModel(title: "全部", contentVC: SubscribedSeriesViewController()),
            CategoryDisplayModel(title: "综艺", contentVC: FilteredSubscribedSeriesViewController(seasonType: 7)),
            CategoryDisplayModel(title: "电影", contentVC: FilteredSubscribedSeriesViewController(seasonType: 2)),
            CategoryDisplayModel(title: "电视剧", contentVC: FilteredSubscribedSeriesViewController(seasonType: 5)),
        ]
        super.viewDidLoad()
        segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 20, weight: .bold)], for: .normal)
        segmentedControl.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(112)
            make.height.equalTo(50)
        }
    }
}

class SubscribedSeriesViewController: StandardVideoCollectionViewController<FollowBangumiListData.Bangumi> {
    private var sortedSubscriptions: [FollowBangumiListData.Bangumi]?
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 24
        collectionVC.showHeader = false
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset = UIEdgeInsets(top: 180, left: 0, bottom: 40, right: 0)
    }

    override func request(page: Int) async throws -> [FollowBangumiListData.Bangumi] {
        if page == 1 || sortedSubscriptions == nil {
            async let bangumi = loadSubscriptions(type: 1)
            async let cinema = loadSubscriptions(type: 2)
            let results = try await (bangumi, cinema)
            sortedSubscriptions = (results.0 + results.1)
                .sorted { ($0.new_ep?.pub_time ?? "") > ($1.new_ep?.pub_time ?? "") }
        }
        let items = sortedSubscriptions ?? []
        let start = (page - 1) * 24
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + 24, items.count)])
    }

    private func loadSubscriptions(type: Int) async throws -> [FollowBangumiListData.Bangumi] {
        var items = [FollowBangumiListData.Bangumi]()
        var page = 1
        while true {
            try Task.checkCancellation()
            let batch = try await WebRequest.requestFollowBangumiList(type: type, page: page)?.list ?? []
            items.append(contentsOf: batch)
            guard batch.count == 24 else { return items }
            page += 1
        }
    }

    override func goDetail(with record: FollowBangumiListData.Bangumi) {
        VideoDetailViewController.create(seasonId: record.season_id, coverURL: record.pic).present(from: self)
    }
}

final class FilteredSubscribedSeriesViewController: SubscribedSeriesViewController {
    let seasonType: Int
    private var sourcePage = 1
    private var pending: [FollowBangumiListData.Bangumi] = []

    init(seasonType: Int) {
        self.seasonType = seasonType
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func request(page: Int) async throws -> [FollowBangumiListData.Bangumi] {
        if page == 1 {
            sourcePage = 1
            pending.removeAll()
        }
        while pending.count < 24 {
            let list = try await WebRequest.requestFollowBangumiList(type: 2, page: sourcePage)?.list ?? []
            sourcePage += 1
            pending.append(contentsOf: list.filter { $0.season_type == seasonType })
            if list.count < 24 { break }
        }
        let result = Array(pending.prefix(24))
        pending.removeFirst(result.count)
        return result
    }
}

class BangumiListViewController: StandardVideoCollectionViewController<FollowBangumiListData.Bangumi> {
    let type: Int
    init(type: Int) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 24
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset = UIEdgeInsets(top: 160, left: 0, bottom: 40, right: 0)
    }

    override func request(page: Int) async throws -> [FollowBangumiListData.Bangumi] {
        let res = try await WebRequest.requestFollowBangumiList(type: type, page: page)
        return res?.list ?? []
    }

    override func goDetail(with record: FollowBangumiListData.Bangumi) {
        let detailVC = VideoDetailViewController.create(seasonId: record.season_id, coverURL: record.pic)
        detailVC.present(from: self)
    }
}

extension WebRequest.EndPoint {
    static let followBangumiList = "https://api.bilibili.com/x/space/bangumi/follow/list"
}

extension WebRequest {
    static func requestFollowBangumiList(type: Int, page: Int = 1) async throws -> FollowBangumiListData? {
        guard let mid = ApiRequest.getToken()?.mid else { return nil }
        return try await request(url: EndPoint.followBangumiList, parameters: ["vmid": mid, "type": type, "pn": page, "ps": "24"])
    }
}

struct FollowBangumiListData: Codable, Hashable {
    struct Bangumi: Codable, Hashable, DisplayData {
        let season_id: Int
        let media_id: Int
        let season_type: Int?
        let title: String
        let cover: URL
        let progress: String?
        let new_ep: NewEp?

        struct NewEp: Codable, Hashable {
            let index_show: String?
            let cover: URL?
            let pub_time: String?
        }

        // DisplayData
        var ownerName: String { return progress ?? "" }
        var pic: URL? { return new_ep?.cover ?? cover }
        var overlay: DisplayOverlay? {
            guard let index_show = new_ep?.index_show else { return nil }
            var leftItems = [DisplayOverlay.DisplayOverlayItem]()
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: index_show))
            var badge: DisplayOverlay.DisplayOverlayBadge?
            if let pub_time = new_ep?.pub_time {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let date = formatter.date(from: pub_time), Calendar.current.isDateInToday(date) {
                    badge = .init(text: "更新了!")
                }
            }
            return DisplayOverlay(leftItems: leftItems, badge: badge)
        }
    }

    let list: [Bangumi]
}

extension FollowBangumiListData.Bangumi: PlayableData {
    var aid: Int { 0 }
    var cid: Int { 0 }
}
