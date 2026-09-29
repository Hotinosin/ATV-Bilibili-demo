//
//  VideoPlayerInfoTabsPlugin.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/5.
//

import AVKit
import UIKit

final class VideoPlayerInfoTabsPlugin: NSObject, CommonPlayerPlugin {
    private enum DiscoverySource {
        case uploader
        case related

        var tabTitle: String {
            switch self {
            case .uploader:
                return "博主视频"
            case .related:
                return "相关视频"
            }
        }

        var emptyText: String {
            switch self {
            case .uploader:
                return "当前没有可展示的博主视频"
            case .related:
                return "当前没有可展示的相关视频"
            }
        }
    }

    var onSelectDiscovery: ((PlayInfo) -> Void)?

    private let currentPlayInfo: PlayInfo
    private let sequenceProvider: VideoSequenceProvider?
    private let uploaderInfoViewController = VideoPlayerDiscoveryInfoViewController(title: DiscoverySource.uploader.tabTitle,
                                                                                    emptyText: DiscoverySource.uploader.emptyText)
    private let relatedInfoViewController = VideoPlayerDiscoveryInfoViewController(title: DiscoverySource.related.tabTitle,
                                                                                   emptyText: DiscoverySource.related.emptyText)
    private let commentsInfoViewController: VideoPlayerCommentsInfoViewController
    private let actionInfoViewController: VideoPlayerActionInfoViewController
    private let relatedCandidates: [PlayInfo]
    private let ownerMid: Int
    private var uploaderEntries = [PlayInfo]()
    private var uploaderLoadTask: Task<Void, Never>?
    private weak var playerVC: AVPlayerViewController?

    init(detail: VideoDetail?, currentPlayInfo: PlayInfo, sequenceProvider: VideoSequenceProvider?) {
        self.currentPlayInfo = currentPlayInfo
        self.sequenceProvider = sequenceProvider
        ownerMid = detail?.View.owner.mid ?? 0
        relatedCandidates = Self.makeRelatedEntries(detail: detail, currentPlayInfo: currentPlayInfo)
        commentsInfoViewController = VideoPlayerCommentsInfoViewController(aid: detail?.View.aid ?? currentPlayInfo.aid)
        actionInfoViewController = VideoPlayerActionInfoViewController(detail: detail)
        super.init()

        let onSelect: (PlayInfo) -> Void = { [weak self] playInfo in
            guard let self else { return }
            let currentSequenceKey = self.sequenceProvider.flatMap { provider in
                MainActor.assumeIsolated {
                    provider.current()?.sequenceKey
                }
            } ?? self.currentPlayInfo.sequenceKey
            guard currentSequenceKey != playInfo.sequenceKey else { return }
            self.onSelectDiscovery?(playInfo)
        }
        uploaderInfoViewController.onSelect = onSelect
        relatedInfoViewController.onSelect = onSelect
        refreshDiscoveryTabs()
        loadUploaderEntriesIfNeeded()
    }

    deinit {
        uploaderLoadTask?.cancel()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        refreshCustomInfoViewControllers()
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        removeCustomInfoViewControllers()
        uploaderLoadTask?.cancel()
        uploaderLoadTask = nil
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        removeCustomInfoViewControllers()
        uploaderLoadTask?.cancel()
        uploaderLoadTask = nil
    }

    private func loadUploaderEntriesIfNeeded() {
        guard ownerMid > 0 else { return }
        uploaderLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await ApiRequest.requestUpSpaceVideo(mid: self.ownerMid, lastAid: nil, pageSize: 18)
                guard !Task.isCancelled else { return }

                var seenAids = Set<Int>()
                let entries = records.compactMap { record -> PlayInfo? in
                    guard record.aid > 0,
                          record.aid != self.currentPlayInfo.aid,
                          seenAids.insert(record.aid).inserted
                    else {
                        return nil
                    }
                    return PlayInfo(aid: record.aid,
                                    title: record.title,
                                    ownerName: record.ownerName,
                                    coverURL: record.pic)
                }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.uploaderEntries = Array(entries.prefix(6))
                    self.refreshDiscoveryTabs()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.uploaderEntries = []
                    self.refreshDiscoveryTabs()
                }
            }
        }
    }

    private func refreshDiscoveryTabs() {
        uploaderInfoViewController.update(entries: uploaderEntries.prefix(6).map(makeViewEntry(from:)))
        relatedInfoViewController.update(entries: relatedCandidates.prefix(6).map(makeViewEntry(from:)))
    }

    private func makeViewEntry(from playInfo: PlayInfo) -> VideoPlayerDiscoveryInfoViewController.Entry {
        VideoPlayerDiscoveryInfoViewController.Entry(playInfo: playInfo,
                                                     displayData: VideoPlayerDiscoveryInfoViewController.DiscoveryDisplayData(title: playInfo.title ?? "",
                                                                                                                              ownerName: playInfo.ownerName ?? "",
                                                                                                                              pic: playInfo.coverURL))
    }

    private func refreshCustomInfoViewControllers() {
        guard let playerVC else { return }
        var controllers = playerVC.customInfoViewControllers.filter {
            $0 !== commentsInfoViewController &&
                $0 !== uploaderInfoViewController &&
                $0 !== relatedInfoViewController &&
                $0 !== actionInfoViewController
        }
        controllers.append(commentsInfoViewController)
        controllers.append(uploaderInfoViewController)
        controllers.append(relatedInfoViewController)
        controllers.append(actionInfoViewController)
        playerVC.customInfoViewControllers = sortedVideoInfoControllers(controllers)
    }

    private func removeCustomInfoViewControllers() {
        guard let playerVC else { return }
        playerVC.customInfoViewControllers.removeAll {
            $0 === commentsInfoViewController ||
                $0 === uploaderInfoViewController ||
                $0 === relatedInfoViewController ||
                $0 === actionInfoViewController
        }
    }

    private static func makeRelatedEntries(detail: VideoDetail?, currentPlayInfo: PlayInfo) -> [PlayInfo] {
        let related = detail?.Related ?? []
        var seenAids = Set<Int>()
        return related.compactMap { info -> PlayInfo? in
            guard info.aid > 0,
                  info.aid != currentPlayInfo.aid,
                  seenAids.insert(info.aid).inserted
            else {
                return nil
            }

            return PlayInfo(aid: info.aid,
                            cid: info.cid,
                            title: info.title,
                            ownerName: info.ownerName,
                            coverURL: info.pic)
        }
    }
}

func sortedVideoInfoControllers(_ controllers: [UIViewController]) -> [UIViewController] {
    let order = ["评论", "视频选集", "合集", "相关视频", "博主视频", "简介", "互动"]
    return controllers.sorted {
        (order.firstIndex(of: $0.title ?? "") ?? order.count) <
            (order.firstIndex(of: $1.title ?? "") ?? order.count)
    }
}

final class VideoEpisodeInfoPlugin: NSObject, CommonPlayerPlugin {
    var onSelect: ((Int) -> Void)?
    var onSelectSeason: ((Int) -> Void)?
    private let infoViewController: VideoEpisodeInfoViewController
    private weak var playerVC: AVPlayerViewController?
    private var seasonsTask: Task<Void, Never>?

    init(sequenceProvider: VideoSequenceProvider, currentPlayInfo: PlayInfo) {
        infoViewController = VideoEpisodeInfoViewController(episodes: MainActor.assumeIsolated { sequenceProvider.playSeq },
                                                            currentKey: currentPlayInfo.sequenceKey)
        super.init()
        infoViewController.onSelect = { [weak self] index in self?.onSelect?(index) }
        infoViewController.onSelectSeason = { [weak self] id in self?.onSelectSeason?(id) }
        if let seasonId = currentPlayInfo.seasonId, seasonId > 0 {
            seasonsTask = Task { [weak self] in
                guard let info = try? await WebRequest.requestBangumiInfo(seasonID: seasonId),
                      !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.infoViewController.updateSeasons(info.seasons ?? [], selected: seasonId)
                }
            }
        }
    }

    deinit { seasonsTask?.cancel() }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        var controllers = playerVC.customInfoViewControllers.filter { $0.title != "视频选集" }
        controllers.append(infoViewController)
        playerVC.customInfoViewControllers = sortedVideoInfoControllers(controllers)
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) { removeInfoViewController() }
    func playerWillCleanUp(playerVC: AVPlayerViewController) { removeInfoViewController() }

    private func removeInfoViewController() {
        playerVC?.customInfoViewControllers.removeAll { $0 === infoViewController }
    }
}

private final class VideoEpisodeInfoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private struct EpisodeDisplayData: DisplayData {
        let title: String
        let ownerName = ""
        let pic: URL?
    }

    var onSelect: ((Int) -> Void)?
    var onSelectSeason: ((Int) -> Void)?
    private let episodes: [PlayInfo]
    private let currentKey: String
    private let seasonRow = UIStackView()
    private let seasonView = UIView()
    private var seasonHeight: NSLayoutConstraint?
    private lazy var collectionView: UICollectionView = {
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                            heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .absolute(235),
                                                                         heightDimension: .absolute(175)),
                                                       subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 12, leading: 32, bottom: 12, trailing: 32)
        section.interGroupSpacing = 28
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.remembersLastFocusedIndexPath = true
        view.register(RelatedVideoCell.self,
                      forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        return view
    }()

    init(episodes: [PlayInfo], currentKey: String) {
        self.episodes = episodes
        self.currentKey = currentKey
        super.init(nibName: nil, bundle: nil)
        title = "视频选集"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: 280)
        let seasonLabel = UILabel()
        seasonLabel.text = "季"
        seasonLabel.textColor = .white
        seasonLabel.font = .systemFont(ofSize: 28, weight: .medium)
        let seasonScroll = UIScrollView()
        seasonScroll.showsHorizontalScrollIndicator = false
        seasonRow.axis = .horizontal
        seasonRow.alignment = .center
        seasonRow.spacing = 18
        seasonView.addSubview(seasonLabel)
        seasonView.addSubview(seasonScroll)
        seasonScroll.addSubview(seasonRow)
        view.addSubview(collectionView)
        view.addSubview(seasonView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        seasonView.translatesAutoresizingMaskIntoConstraints = false
        seasonLabel.translatesAutoresizingMaskIntoConstraints = false
        seasonScroll.translatesAutoresizingMaskIntoConstraints = false
        seasonRow.translatesAutoresizingMaskIntoConstraints = false
        seasonHeight = seasonView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            seasonView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            seasonView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            seasonView.topAnchor.constraint(equalTo: view.topAnchor),
            seasonHeight!,
            seasonLabel.leadingAnchor.constraint(equalTo: seasonView.leadingAnchor, constant: 32),
            seasonLabel.centerYAnchor.constraint(equalTo: seasonView.centerYAnchor),
            seasonScroll.leadingAnchor.constraint(equalTo: seasonLabel.trailingAnchor, constant: 24),
            seasonScroll.trailingAnchor.constraint(equalTo: seasonView.trailingAnchor),
            seasonScroll.centerYAnchor.constraint(equalTo: seasonView.centerYAnchor),
            seasonScroll.heightAnchor.constraint(equalToConstant: 68),
            seasonRow.leadingAnchor.constraint(equalTo: seasonScroll.contentLayoutGuide.leadingAnchor),
            seasonRow.trailingAnchor.constraint(equalTo: seasonScroll.contentLayoutGuide.trailingAnchor),
            seasonRow.topAnchor.constraint(equalTo: seasonScroll.contentLayoutGuide.topAnchor),
            seasonRow.bottomAnchor.constraint(equalTo: seasonScroll.contentLayoutGuide.bottomAnchor),
            seasonRow.heightAnchor.constraint(equalTo: seasonScroll.frameLayoutGuide.heightAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: seasonView.bottomAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        seasonView.isHidden = true
    }

    func updateSeasons(_ seasons: [BangumiInfo.Season], selected: Int) {
        guard seasons.count > 1 else { return }
        seasonRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for season in seasons {
            let button = SeasonFilterButton()
            button.setTitle(season.season_title ?? "季 \(season.season_id)", for: .normal)
            button.isSelected = season.season_id == selected
            button.addAction(UIAction { [weak self] _ in
                self?.onSelectSeason?(season.season_id)
            }, for: .primaryActionTriggered)
            seasonRow.addArrangedSubview(button)
        }
        seasonView.isHidden = false
        seasonHeight?.constant = 80
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let index = episodes.firstIndex(where: { $0.sequenceKey == currentKey }) else { return }
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { episodes.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self),
                                                      for: indexPath) as! RelatedVideoCell
        let episode = episodes[indexPath.item]
        cell.update(data: EpisodeDisplayData(title: episode.title ?? "第\(indexPath.item + 1)集",
                                             pic: episode.coverURL))
        cell.alpha = 1
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard episodes[indexPath.item].sequenceKey != currentKey else { return }
        onSelect?(indexPath.item)
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        guard let index = episodes.firstIndex(where: { $0.sequenceKey == currentKey }) else { return nil }
        return IndexPath(item: index, section: 0)
    }
}

private final class VideoPlayerCommentsInfoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let aid: Int
    private var replies = [Replys.Reply]()
    private let viewport = UIView()
    private let fadeMask = CAGradientLayer()
    private lazy var collectionView: UICollectionView = {
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                            heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                       heightDimension: .absolute(80)),
                                                       subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 12, leading: 68, bottom: 12, trailing: 68)
        section.interGroupSpacing = 8
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.register(CompactReplyCell.self, forCellWithReuseIdentifier: CompactReplyCell.identifier)
        return view
    }()

    init(aid: Int) {
        self.aid = aid
        super.init(nibName: nil, bundle: nil)
        title = "评论"
        WebRequest.requestReplys(aid: aid) { [weak self] result in
            self?.replies = result.replies ?? []
            self?.collectionView.reloadData()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: 280)
        view.addSubview(viewport)
        viewport.addSubview(collectionView)
        fadeMask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor,
                           UIColor.white.cgColor, UIColor.clear.cgColor]
        fadeMask.locations = [0, 0.1, 0.9, 1]
        viewport.layer.mask = fadeMask
        viewport.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewport.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewport.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewport.topAnchor.constraint(equalTo: view.topAnchor),
            viewport.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: viewport.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: viewport.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: viewport.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: viewport.bottomAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fadeMask.frame = viewport.bounds
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { replies.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CompactReplyCell.identifier, for: indexPath) as! CompactReplyCell
        cell.config(replay: replies[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        present(ReplyDetailViewController(reply: replies[indexPath.item], aid: aid), animated: true)
    }
}
