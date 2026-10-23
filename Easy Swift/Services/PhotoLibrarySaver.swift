//
//  PhotoLibrarySaver.swift
//  Easy Swift
//
//  把解析结果存进相册：普通图片、视频，以及**实况照片（Live Photo）**。
//
//  实况照片不是"存一张图再存一段视频"——相册要靠一对相同的资源标识把它们配起来：
//  - 静态图：JPEG 里写 `MakerApple[17] = <identifier>`
//  - 视频：MOV 的元数据写 `com.apple.quicktime.content.identifier = <identifier>`
//  两个值不一致，相册就只认成"一张照片 + 一段视频"。
//

import AVFoundation
import Foundation
import ImageIO
import Photos
import SwiftUtils
import UniformTypeIdentifiers

enum PhotoLibrarySaver {
    /// 只申请"写入"权限：我们不需要读用户的相册
    static func requestAddAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        debugPrint("[相册] 写入权限状态=\(status.rawValue)")
        return status == .authorized || status == .limited
    }

    /// 保存一张图片；`motion` 非空时合成为实况照片
    static func save(image remoteImage: URL, motion remoteMotion: URL? = nil) async throws {
        guard await requestAddAccess() else { throw MediaSaveError.permissionDenied }

        let imageFile = try await MediaDownloader.download(remoteImage)
        defer { try? FileManager.default.removeItem(at: imageFile) }

        if let remoteMotion {
            let motionFile = try await MediaDownloader.download(remoteMotion)
            defer { try? FileManager.default.removeItem(at: motionFile) }

            let pair = try await LivePhotoPair.make(still: imageFile, motion: motionFile)
            defer {
                try? FileManager.default.removeItem(at: pair.image)
                try? FileManager.default.removeItem(at: pair.video)
            }
            try await addToLibrary {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: pair.image, options: options)
                request.addResource(with: .pairedVideo, fileURL: pair.video, options: options)
            }
            debugPrint("[相册] 已保存实况照片")
            return
        }

        try await addToLibrary {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: imageFile, options: nil)
        }
        debugPrint("[相册] 已保存图片")
    }

    /// 保存视频
    static func save(video remoteVideo: URL) async throws {
        guard await requestAddAccess() else { throw MediaSaveError.permissionDenied }
        let file = try await MediaDownloader.download(remoteVideo)
        defer { try? FileManager.default.removeItem(at: file) }
        try await addToLibrary {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: file, options: nil)
        }
        debugPrint("[相册] 已保存视频")
    }

    /// 保存后回读相册确认它真的是实况照片（`performChanges` 不报错 ≠ 存对了）。
    ///
    /// 回读属于"读相册"，需要读权限；我们平时只申请了写入权限，
    /// 所以这里先看授权状态：没读权限就返回 `nil`（**不下结论**），
    /// 而不是返回 false 让界面误报"没存成实况照片"。
    static func verifyLatestIsLivePhoto() -> Bool? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            debugPrint("[相册] 没有读权限，跳过实况照片回读校验")
            return nil
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else { return false }
        return asset.mediaSubtypes.contains(.photoLive)
    }

    // MARK: - 内部

    private static func addToLibrary(_ changes: @escaping () -> Void) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges(changes)
        } catch {
            throw MediaSaveError.saveFailed(error.localizedDescription)
        }
    }
}

// MARK: - 实况照片配对

enum LivePhotoPair {
    /// 生成一对带相同资源标识的 (JPEG, MOV)
    static func make(still: URL, motion: URL) async throws -> (image: URL, video: URL) {
        let identifier = UUID().uuidString
        let imageURL = try embedIdentifier(inStill: still, identifier: identifier)
        let videoURL = try await embedIdentifier(inMovie: motion, identifier: identifier)
        return (imageURL, videoURL)
    }

    /// 静态图：转成 JPEG 并写入 MakerApple 的 17 号字段
    private static func embedIdentifier(inStill url: URL, identifier: String) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw MediaSaveError.invalidImage
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("easyswift-live-\(UUID().uuidString).jpg")
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL,
                                                                UTType.jpeg.identifier as CFString,
                                                                1, nil)
        else {
            throw MediaSaveError.livePhotoBuildFailed("无法创建 JPEG 输出")
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyMakerAppleDictionary: ["17": identifier],
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaSaveError.livePhotoBuildFailed("JPEG 写入失败")
        }
        return output
    }

    /// 视频：导出为 MOV，并写入 content.identifier
    private static func embedIdentifier(inMovie url: URL, identifier: String) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw MediaSaveError.livePhotoBuildFailed("无法创建导出会话")
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("easyswift-live-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: output)

        session.outputURL = output
        session.outputFileType = .mov

        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = "com.apple.quicktime.content.identifier" as NSString
        item.value = identifier as NSString
        session.metadata = [item]

        if #available(iOS 18.0, macOS 15.0, *) {
            try await session.export(to: output, as: .mov)
        } else {
            session.outputURL = output
            session.outputFileType = .mov
            await session.export()
            if session.status != .completed {
                throw MediaSaveError.livePhotoBuildFailed(session.error?.localizedDescription ?? "导出未完成")
            }
        }
        return output
    }
}
