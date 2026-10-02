//
//  BVideoInfoPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVKit
import Kingfisher

class BVideoInfoPlugin: NSObject, CommonPlayerPlugin {
    let title: String?
    let subTitle: String?
    let desp: String?
    let pic: URL?
    let viewPoints: [PlayerInfo.ViewPoint]?
    private weak var configuredPlayer: AVPlayer?
    private weak var playerVC: AVPlayerViewController?
    private var metadataTask: Task<Void, Never>?

    init(title: String?, subTitle: String?, desp: String?, pic: URL?, viewPoints: [PlayerInfo.ViewPoint]?) {
        self.title = title
        self.subTitle = subTitle
        let description = desp?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.desp = description.isEmpty ? "暂无简介" : description
        self.pic = pic
        self.viewPoints = viewPoints
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        if let player = playerVC.player {
            updatePlayerInfo(player: player)
        }
    }

    func playerWillStart(player: AVPlayer) {
        updatePlayerInfo(player: player)
    }

    func playerDidChange(player: AVPlayer) {
        updatePlayerInfo(player: player)
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        metadataTask?.cancel()
        metadataTask = nil
        configuredPlayer = nil
        self.playerVC = nil
    }

    deinit { metadataTask?.cancel() }

    private func updatePlayerInfo(player: AVPlayer) {
        guard configuredPlayer !== player else { return }
        configuredPlayer = player
        metadataTask?.cancel()
        MainActor.callSafely {
            guard self.playerVC?.player === player else { return }
            AVPlayerMetaUtils.setTextInfo(title: self.title, subTitle: self.subTitle, desp: self.desp, player: player)
            if let playerVC = self.playerVC {
                playerVC.customInfoViewControllers = sortedVideoInfoControllers(playerVC.customInfoViewControllers)
            }
        }
        metadataTask = Task {
            async let info: () = AVPlayerMetaUtils.setPlayerInfo(title: title, subTitle: subTitle, desp: desp, pic: pic, player: player)
            if let viewPoints {
                async let vp: () = updatePlayerCharpter(viewPoints: viewPoints, player: player)
                await vp
            }
            await info
        }
    }

    private func updatePlayerCharpter(viewPoints: [PlayerInfo.ViewPoint], player: AVPlayer) async {
        guard let playerItem = player.currentItem else { return }
        _ = await withTaskGroup(of: Void.self) { group in
            for viewPoint in viewPoints {
                group.addTask {
                    if let pic = viewPoint.imgUrl?.addSchemeIfNeed(),
                       let result = try? await KingfisherManager.shared.retrieveImage(
                           with: Kingfisher.ImageResource(downloadURL: pic),
                           options: [
                               .onlyLoadFirstFrame,
                               .processor(DownsamplingImageProcessor(size: CGSize(width: 320, height: 180))),
                           ]
                       ),
                       let data = result.image.pngData()
                    {
                        viewPoint.imageData = data
                    }
                }
            }
            return group
        }

        let metas = viewPoints.compactMap { convertTimedMetadataGroup(viewPoint: $0) }

        guard !Task.isCancelled else { return }
        MainActor.callSafely {
            guard player.currentItem === playerItem else { return }
            playerItem.navigationMarkerGroups = [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: metas)]
        }
    }

    private func convertTimedMetadataGroup(viewPoint: PlayerInfo.ViewPoint) -> AVTimedMetadataGroup {
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: viewPoint.content,
        ]
        var metadatas = mapping.compactMap { AVPlayerMetaUtils.createMetadataItem(for: $0, value: $1) }
        let timescale: Int32 = 600
        let cmStartTime = CMTimeMakeWithSeconds(viewPoint.from, preferredTimescale: timescale)
        let cmEndTime = CMTimeMakeWithSeconds(viewPoint.to, preferredTimescale: timescale)
        let timeRange = CMTimeRangeFromTimeToTime(start: cmStartTime, end: cmEndTime)
        if let imageData = viewPoint.imageData,
           let item = AVPlayerMetaUtils.createMetadataItem(for: .commonIdentifierArtwork, value: imageData)
        {
            metadatas.append(item)
        }

        return AVTimedMetadataGroup(items: metadatas, timeRange: timeRange)
    }
}

extension KingfisherManager {
    func retrieveImage(with resource: Resource,
                       options: KingfisherOptionsInfo? = nil) async throws -> RetrieveImageResult
    {
        try await withCheckedThrowingContinuation { conf in
            retrieveImage(with: resource, options: options) { result in
                switch result {
                case let .success(result):
                    conf.resume(returning: result)
                case let .failure(err):
                    conf.resume(throwing: err)
                }
            }
        }
    }
}
