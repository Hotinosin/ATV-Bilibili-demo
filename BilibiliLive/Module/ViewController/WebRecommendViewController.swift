import Foundation
import UIKit

final class WebRecommendViewController: StandardVideoCollectionViewController<WebRecommendItem> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 12
        collectionVC.isShowCove = true
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset.top = SegmentViewController.contentTopInset
    }

    override func request(page: Int) async throws -> [WebRecommendItem] {
        collectionVC.headerText = "网页端推荐"
        let response = try await WebRequest.requestTopFeedRecommend(pageIndex: page)
        return response.item.compactMap(WebRecommendItem.init)
    }
}

struct WebRecommendItem: PlayableData {
    let aid: Int
    let cid: Int
    let title: String
    let ownerName: String
    let pic: URL?
    let avatar: URL?
    let date: String?
    let duration: Int
    let viewCount: Int
    let danmakuCount: Int

    init?(_ item: WebTopFeedRecommendResponse.Item) {
        guard item.goto == "av",
              let aid = item.id, aid > 0,
              let cid = item.cid, cid > 0,
              let title = item.title, !title.isEmpty
        else { return nil }

        self.aid = aid
        self.cid = cid
        self.title = title
        ownerName = item.owner?.name ?? ""
        pic = item.pic.flatMap(URL.init(string:))?.addSchemeIfNeed()
        avatar = item.owner?.face.flatMap(URL.init(string:))?.addSchemeIfNeed()
        date = item.rcmd_reason?.content
        duration = item.duration ?? 0
        viewCount = item.stat?.view ?? 0
        danmakuCount = item.stat?.danmaku ?? 0
    }

    var overlay: DisplayOverlay? {
        DisplayOverlay(
            leftItems: [
                .init(icon: "play.rectangle", text: viewCount.numberString()),
                .init(icon: "list.bullet.rectangle", text: danmakuCount.numberString()),
            ],
            rightItems: [.init(icon: nil, text: TimeInterval(duration).timeString())]
        )
    }
}
