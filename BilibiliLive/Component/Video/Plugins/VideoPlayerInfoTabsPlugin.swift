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
    let order = ["评论", "合集", "相关视频", "博主视频", "互动"]
    return controllers.sorted {
        (order.firstIndex(of: $0.title ?? "") ?? order.count) <
            (order.firstIndex(of: $1.title ?? "") ?? order.count)
    }
}

private final class VideoPlayerCommentsInfoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private var replies = [Replys.Reply]()
    private lazy var collectionView: UICollectionView = {
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                            heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                       heightDimension: .absolute(180)),
                                                       subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 8, leading: 32, bottom: 8, trailing: 32)
        section.interGroupSpacing = 4
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.register(UINib(nibName: ReplyCell.identifier, bundle: nil), forCellWithReuseIdentifier: ReplyCell.identifier)
        return view
    }()

    init(aid: Int) {
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
        preferredContentSize = CGSize(width: 0, height: 460)
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { replies.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReplyCell.identifier, for: indexPath) as! ReplyCell
        cell.config(replay: replies[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        present(ReplyDetailViewController(reply: replies[indexPath.item]), animated: true)
    }
}
