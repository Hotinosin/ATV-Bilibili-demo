import AVKit
import UIKit

final class VideoCollectionInfoPlugin: NSObject, CommonPlayerPlugin {
    var onSelect: ((PlayInfo) -> Void)?

    private let infoViewController: VideoCollectionInfoViewController
    private weak var playerVC: AVPlayerViewController?

    init(episodes: [VideoDetail.Info.UgcSeason.UgcVideoInfo], currentAid: Int) {
        infoViewController = VideoCollectionInfoViewController(episodes: episodes, currentAid: currentAid)
        super.init()
        infoViewController.onSelect = { [weak self] info in
            self?.onSelect?(info)
        }
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        var controllers = playerVC.customInfoViewControllers.filter { $0.title != "合集" }
        controllers.append(infoViewController)
        playerVC.customInfoViewControllers = controllers
    }

    func playerDidCleanUp(player: AVPlayer) {
        removeInfoViewController()
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        removeInfoViewController()
    }

    private func removeInfoViewController() {
        playerVC?.customInfoViewControllers.removeAll { $0 === infoViewController }
    }
}

private final class VideoCollectionInfoViewController: UIViewController {
    var onSelect: ((PlayInfo) -> Void)?

    private let episodes: [VideoDetail.Info.UgcSeason.UgcVideoInfo]
    private let currentAid: Int
    private lazy var collectionView: UICollectionView = {
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                            heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .absolute(320),
                                                                         heightDimension: .absolute(248)),
                                                       subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 28, leading: 32, bottom: 28, trailing: 32)
        section.interGroupSpacing = 28
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary

        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.remembersLastFocusedIndexPath = true
        view.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        return view
    }()

    init(episodes: [VideoDetail.Info.UgcSeason.UgcVideoInfo], currentAid: Int) {
        self.episodes = episodes
        self.currentAid = currentAid
        super.init(nibName: nil, bundle: nil)
        title = "合集"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: 360)
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension VideoCollectionInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        episodes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let episode = episodes[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self),
                                                      for: indexPath) as! RelatedVideoCell
        cell.update(data: episode)
        cell.alpha = episode.aid == currentAid ? 0.55 : 1
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let episode = episodes[indexPath.item]
        guard episode.aid != currentAid else { return }
        onSelect?(PlayInfo(aid: episode.aid, cid: episode.cid, title: episode.title))
    }
}
