//
//  BannerViewModel.swift
//  BilibiliLive
//
//  Created by iManTie on 10/11/25.
//

import UIKit
import SwiftUI

class BannerViewModel: ObservableObject {
    @Published var favdatas: [FavData] = []
    @Published var selectData: FavData?

    @Published var offsetY: CGFloat = 0
    @Published var currentIndex = 0
    @Published var resetFouce = 0
    
    @Published var isAnimate = true
    
    var focusedBannerButton: (() -> Void)?
    var overMoveLeft: (() -> Void)?
    var playAction: ((_ data: FavData) -> Void)?
    var detailAction: ((_ data: FavData) -> Void)?
    
    func createDatas() {
        let ower = VideoOwner(mid: 3493082095946091, name: "不再犹豫的达达猪", face: "https://i0.hdslb.com/bfs/face/e6035d9cdc7df738988ccd6893b800106ef36201.jpg")
        let data1 = FavData(cover: "https://i0.hdslb.com/bfs/archive/79a14985ca2240cd7fb224bf264edd524616d3c4.jpg", upper: ower, id: 935456, title: "【巫师3 新手攻略】【巫师3 新手攻略】【巫师3 新手攻略】【巫师3 新手攻略】【巫师3 新手攻略】", duration: 0, cnt_info: nil, pubtime: 0, intro: "「艾尔登法环」「ELDEN RING」7个“大卢恩”—6个“神授塔”（葛瑞克、拉卡德、拉塔恩、蒙葛特、蒙格、玛丽妮亚、无缘诞生者的大卢恩）（宁姆格福、西亚坛、盖利德、东亚坛、孤立、利耶尼亚神授塔）")
        let data2 = FavData(cover: "https://archive.biliimg.com/bfs/archive/eb80c516bfeb6ff0d9220bf723aea565d98c46d2.jpg", upper: ower, id: 935457, title: "【巫师3 新手攻略】", duration: 0, cnt_info: nil, pubtime: 0, intro: "「艾尔登法环」")
        let data3 = FavData(cover: "https://archive.biliimg.com/bfs/archive/158c399607224ee95a5f7ba69a98787e5bf216be.jpg", upper: ower, id: 935458, title: "【巫师3 新手攻略】", duration: 0, cnt_info: nil, pubtime: 0, intro: "「艾尔登法环」「ELDEN RING」7个“大卢恩”—6个“神授塔”（葛瑞克、拉卡德、拉塔恩、蒙葛特、蒙格、玛丽妮亚、无缘诞生者的大卢恩）（宁姆格福、西亚坛、盖利德、东亚坛、孤立、利耶尼亚神授塔）")

        favdatas = [data1, data2, data3]
        selectData = favdatas.first
    }

    @MainActor
    func loadFavList(isReset: Bool = true) async throws {
        let favList = try? await WebRequest.requestFavVideosList()
        if favList?.count ?? 0 > 0 {
            let result = try await WebRequest.requestFavVideos(mid: String(favList?.first?.id ?? 0), page: 0)
            await MainActor.run {
                favdatas = result
                if isReset {
                    self.selectData = self.favdatas.first
                    self.currentIndex = self.selectData?.id ?? 0
                    self.resetFouce = resetFouce + 1
                }
            }
        }
    }

    func setIndex(index: Int) {
        if index < favdatas.count {
            selectData = favdatas[index]
            currentIndex = selectData?.id ?? 0
        }
    }
}
