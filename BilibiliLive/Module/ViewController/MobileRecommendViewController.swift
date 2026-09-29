//
//  MobileRecommendViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/5/19.
//

import UIKit

class MobileRecommendViewController: StandardVideoCollectionViewController<ApiRequest.FeedResp.Items> {
    private var nextIdx: Int?

    override func applyReloadedData(_ records: [ApiRequest.FeedResp.Items]) {
        let previous = collectionVC.displayDatas.compactMap { $0 as? ApiRequest.FeedResp.Items }
        let previousIDs = Set(previous.map(\.param))
        let newRecords = records.filter { !previousIDs.contains($0.param) }
        collectionVC.oldRecommendationsStartIndex = newRecords.isEmpty || previous.isEmpty ? nil : newRecords.count
        collectionVC.displayDatas = newRecords + previous
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 1
        collectionVC.isShowCove = true
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset.top = SegmentViewController.contentTopInset
    }

    override func request(page: Int) async throws -> [ApiRequest.FeedResp.Items] {
        collectionVC.headerText = "移动端推荐"
        if page == 1 {
            let result = try await ApiRequest.getFeedsPage()
            nextIdx = result.nextIdx
            return result.items
        } else if let nextIdx {
            let result = try await ApiRequest.getFeedsPage(lastIdx: nextIdx)
            guard result.nextIdx != nextIdx else { return [] }
            guard self.nextIdx == nextIdx else { return [] }
            self.nextIdx = result.nextIdx
            return result.items
        } else {
            throw NSError(domain: "", code: -1)
        }
    }
}

extension ApiRequest.FeedResp.Items: PlayableData {
    var aid: Int { Int(param) ?? 0 }
    var cid: Int { player_args?.cid ?? 0 }
}
