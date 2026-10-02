//
//  AVPlayerMetaUtils.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/6.
//

import AVKit
import Kingfisher
import MediaPlayer

enum AVPlayerMetaUtils {
    @MainActor
    static func setTextInfo(title: String?, subTitle: String?, desp: String?, player: AVPlayer) {
        let desp = desp?.components(separatedBy: "\n").joined(separator: " ")
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: title,
            .iTunesMetadataTrackSubTitle: subTitle,
            .commonIdentifierDescription: desp,
        ]
        player.currentItem?.externalMetadata = mapping.compactMap { createMetadataItem(for: $0, value: $1) }
    }

    @MainActor
    static func setPlayerInfo(title: String?, subTitle: String?, desp: String?, pic: URL?, player: AVPlayer) async {
        guard let playerItem = player.currentItem else { return }
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title ?? "",
            MPMediaItemPropertyArtist: subTitle ?? "",
        ]

        if let pic = pic,
           let resource = try? await KingfisherManager.shared.retrieveImage(
               with: Kingfisher.ImageResource(downloadURL: pic),
               options: [
                   .onlyLoadFirstFrame,
                   .processor(DownsamplingImageProcessor(size: CGSize(width: 640, height: 360))),
               ]
           ),
           let data = resource.image.pngData(),
           let item = createMetadataItem(for: .commonIdentifierArtwork, value: data)
        {
            guard !Task.isCancelled, player.currentItem === playerItem else { return }
            playerItem.externalMetadata.append(item)

            let artwork = MPMediaItemArtwork(boundsSize: resource.image.size) { _ in resource.image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        guard !Task.isCancelled, player.currentItem === playerItem else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    static func createMetadataItem(for identifier: AVMetadataIdentifier, value: Any?) -> AVMetadataItem? {
        if value == nil { return nil }
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        // Specify "und" to indicate an undefined language.
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }
}
