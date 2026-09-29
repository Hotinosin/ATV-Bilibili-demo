//
//  HistoryViewController.swift
//  BilibiliLive
//
//  Created by whw on 2021/4/15.
//

import Alamofire
import SwiftyJSON
import UIKit

class HistoryViewController: UIViewController {
    let collectionVC = FeedCollectionViewController()
    var didSelectToLastLeft: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.showHeader = false
        collectionVC.show(in: self)
        collectionVC.collectionView.contentInset.top = SegmentViewController.contentTopInset
        collectionVC.didSelectToLastLeft = didSelectToLastLeft
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! HistoryData)
        }
    }

    func goDetail(with history: HistoryData) {
        let detailVC: VideoDetailViewController
        if let epId = history.bangumi?.ep_id, epId > 0 {
            detailVC = VideoDetailViewController.create(epid: epId)
        } else if let seasonId = history.bangumi?.season?.season_id, seasonId > 0 {
            detailVC = VideoDetailViewController.create(seasonId: seasonId)
        } else {
            detailVC = VideoDetailViewController.create(aid: history.aid, cid: history.cid ?? 0)
        }
        detailVC.setHistoryProgress(history)
        detailVC.present(from: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
}

extension HistoryViewController: BLTabBarContentVCProtocol {
    func reloadData() {
        WebRequest.requestHistory { [weak self] datas in
            self?.collectionVC.displayDatas = datas
        }
    }
}
