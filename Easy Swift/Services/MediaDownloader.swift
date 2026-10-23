//
//  MediaDownloader.swift
//  Easy Swift
//
//  把远端媒体下载到临时文件（带防盗链头、扩展名按内容判定）。
//  保存到相册、Live Photo 合成都需要"本地文件"，这里统一出口。
//

import Foundation
import SwiftUtils

enum MediaDownloader {
    /// 下载到临时目录，返回带正确扩展名的文件 URL
    static func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        for (key, value) in headers(for: url) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MediaSaveError.downloadFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw MediaSaveError.downloadFailed("HTTP \(code)")
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        let ext = fileExtension(contentType: contentType, data: data, url: url)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("easyswift-\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: fileURL)
        } catch {
            throw MediaSaveError.downloadFailed(error.localizedDescription)
        }
        debugPrint("[媒体] 下载完成 \(data.count) 字节 type=\(contentType) -> .\(ext)")
        return fileURL
    }

    static func headers(for url: URL) -> [String: String] {
        var headers = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        ]
        guard let host = url.host else { return headers }
        if host.contains("xiaohongshu.com") || host.contains("xhscdn.com") {
            headers["Referer"] = "https://www.xiaohongshu.com/"
        } else if host.contains("douyin") || host.contains("douyinpic") || host.contains("byteimg") {
            headers["Referer"] = "https://www.douyin.com/"
        }
        return headers
    }

    /// Content-Type → 魔数 → URL 已知扩展名。
    /// 抖音直链常常没有扩展名，只靠 URL 猜会把 mp4 存成 jpg
    static func fileExtension(contentType: String, data: Data, url: URL) -> String {
        let type = contentType.lowercased()
        if type.contains("mp4") { return "mp4" }
        if type.contains("quicktime") { return "mov" }
        if type.contains("webm") { return "webm" }
        if type.contains("webp") { return "webp" }
        if type.contains("png") { return "png" }
        if type.contains("gif") { return "gif" }
        if type.contains("jpeg") || type.contains("jpg") { return "jpg" }
        if type.contains("heic") { return "heic" }

        let head = [UInt8](data.prefix(12))
        if head.count >= 8, head[4] == 0x66, head[5] == 0x74, head[6] == 0x79, head[7] == 0x70 { return "mp4" } // ftyp
        if head.count >= 2, head[0] == 0xFF, head[1] == 0xD8 { return "jpg" }
        if head.count >= 2, head[0] == 0x89, head[1] == 0x50 { return "png" }
        if head.count >= 12, head[0] == 0x52, head[1] == 0x49, head[8] == 0x57, head[9] == 0x45 { return "webp" }

        let known: Set<String> = ["mp4", "mov", "m4v", "webm", "jpg", "jpeg", "png", "webp", "gif", "heic"]
        let pathExt = url.pathExtension.lowercased()
        if known.contains(pathExt) { return pathExt }
        return "bin"
    }
}

/// 保存相关的错误：文案直接面向用户，不要出现状态码以外的技术词
enum MediaSaveError: LocalizedError {
    case permissionDenied
    case permissionUndetermined
    case downloadFailed(String)
    case invalidImage
    case livePhotoBuildFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有相册写入权限，请到「设置 → 隐私与安全性 → 照片」里允许"
        case .permissionUndetermined:
            return "还没获得相册权限"
        case let .downloadFailed(reason):
            return "下载失败：\(reason)"
        case .invalidImage:
            return "这张图无法转成相册支持的格式"
        case let .livePhotoBuildFailed(reason):
            return "动图合成失败：\(reason)"
        case let .saveFailed(reason):
            return "保存失败：\(reason)"
        }
    }
}
