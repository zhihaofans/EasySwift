//
//  RemoteImageCache.swift
//  Easy Swift
//
//  远程图片缓存：内存 + 磁盘 + 请求合并，解码时按 EXIF 方向转正并缩到目标像素。
//
//  为什么值得单独做一层：
//  - 历史列表、解析结果、预览三处各自 `URLSession` 拉原图，滚动一次就重下一次；
//  - 原图动辄 2000+ px，直接 `PlatformImage(data:)` 会整张解码进内存，列表里几十行就顶到内存峰值；
//  - 竖拍照片带 EXIF 方向，取缩略图时不转正会"躺倒"，而且只在部分照片上出现。
//    SwiftUtils 0.0.33 的 `ImageUtil.downsample` 带 `kCGImageSourceCreateThumbnailWithTransform`，这里直接用它。
//
//  缓存键 = URL + 目标像素：同一张图在列表（小）和预览（大）里是两份，互不污染。
//

import CryptoKit
import Foundation
import SwiftUtils
import UniformTypeIdentifiers

/// 跨 actor 传递的图片包装（UIImage / NSImage 本身不是 Sendable）。
/// 必须是 class：`NSCache` 的值类型要求引用类型。
final class CachedImage: @unchecked Sendable {
    let image: PlatformImage

    init(_ image: PlatformImage) {
        self.image=image
    }
}

actor RemoteImageCache {
    /// 加载失败类型：展示层要区分「不是图片」和「网络失败」，文案不同
    enum LoadError: LocalizedError {
        case httpStatus(Int)
        case notImage
        case transport(String)

        var errorDescription: String? {
            switch self {
            case let .httpStatus(code): return "HTTP \(code)"
            case .notImage: return "返回内容不是图片"
            case let .transport(message): return message
            }
        }
    }

    typealias Fetcher=@Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let shared=RemoteImageCache()

    private let memory=NSCache<NSString, CachedImage>()
    private var inFlight: [String: Task<CachedImage, Error>]=[:]
    private let directory: URL
    private let fetcher: Fetcher

    /// - Parameters:
    ///   - directory: 磁盘缓存目录，默认 `Caches/RemoteImages`
    ///   - fetcher: 网络实现，默认 URLSession；测试时注入假数据，避免真联网
    init(directory: URL? = nil, fetcher: Fetcher? = nil) {
        let base=FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory=directory ?? base.appendingPathComponent("RemoteImages", isDirectory: true)
        self.fetcher=fetcher ?? { request in
            try await URLSession.shared.data(for: request)
        }
        memory.countLimit=200
        memory.totalCostLimit=64 * 1024 * 1024

        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// 取图：内存 → 磁盘 → 网络。同一 URL+尺寸的并发请求会合并成一次下载。
    /// - Parameter maxPixelSize: 最长边像素（不是点数）；列表缩略图给 200 就够，全屏预览给 3000 级
    func image(for url: URL, referer: String? = nil, maxPixelSize: Int) async throws -> CachedImage {
        let key=Self.key(url: url, maxPixelSize: maxPixelSize)

        if let cached=memory.object(forKey: key as NSString) {
            debugPrint(.ui, "[图片缓存] 命中内存 \(url.host ?? "?")\(url.path.prefix(40))")
            return cached
        }
        if let task=inFlight[key] {
            return try await task.value
        }

        let task=Task<CachedImage, Error> { [directory, fetcher] in
            let diskFile=directory.appendingPathComponent(Self.fileName(for: key))
            if let data=try? Data(contentsOf: diskFile),
               let image=PlatformImage(data: data)
            {
                debugPrint(.ui, "[图片缓存] 命中磁盘 \(url.host ?? "?")\(url.path.prefix(40))")
                return CachedImage(image)
            }

            var request=URLRequest(url: url)
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            if let referer, !referer.isEmpty {
                request.setValue(referer, forHTTPHeaderField: "Referer")
            }

            let started=Date()
            let data: Data
            do {
                let (body, response)=try await fetcher(request)
                if let http=response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw LoadError.httpStatus(http.statusCode)
                }
                data=body
            } catch let error as LoadError {
                throw error
            } catch {
                throw LoadError.transport(error.localizedDescription)
            }

            // 按 EXIF 方向转正 + 缩到目标像素（ImageIO 直接出缩略图，不解码原图）
            guard let cgImage=ImageUtil.downsample(data, maxPixelSize: maxPixelSize) else {
                throw LoadError.notImage
            }

            // 落盘用重编码后的 JPEG：体积小、方向已归一，下次直接读，省掉重复解码
            if let encoded=ImageUtil.reencode(data, to: .jpeg, quality: 0.85, maxPixelSize: maxPixelSize) {
                try? encoded.write(to: diskFile, options: [.atomic])
            }
            let cost=Int(Date().timeIntervalSince(started) * 1000)
            debugPrint(.ui, "[图片缓存] 网络下载 \(url.host ?? "?")\(url.path.prefix(30)) \(data.count / 1024)KB \(cost)ms max=\(maxPixelSize)")
            return CachedImage(PlatformImage.from(cgImage: cgImage))
        }
        inFlight[key]=task

        do {
            let result=try await task.value
            memory.setObject(result, forKey: key as NSString, cost: Self.cost(of: result.image))
            inFlight[key]=nil
            return result
        } catch {
            inFlight[key]=nil
            throw error
        }
    }

    /// 清空内存（磁盘保留）：内存警告时调用
    func clearMemory() {
        memory.removeAllObjects()
    }

    // MARK: - 键与文件

    static func key(url: URL, maxPixelSize: Int) -> String {
        "\(canonical(url: url))#\(maxPixelSize)"
    }

    /// 把 URL 规范化成"同一个图就是同一个键"。
    ///
    /// 抖音/小红书的 CDN 图片地址有两层不稳定：
    /// 1. query 带时效签名（`x-expires` / `x-signature` / `biz_tag`），**每次解析都换**；
    /// 2. **子域名也会换** —— 实测同一张图 `…/tos-cn-i-0813/ogDaEaIG…` 这次在 `p3-pc-sign.douyinpic.com`，
    ///    下次在 `p11-sign.douyinpic.com`（真机日志 2026-11-18）。
    /// 所以 CDN 图只按 **path** 做键：图片变体（`~tplv-dy-aweme-images:q75.webp`）本来就在 path 里。
    /// 代价：万一两个域名下 path 相同却是不同内容，会显示错图 —— 这些 CDN 的 path 是内容哈希，不会撞。
    static func canonical(url: URL) -> String {
        let host=(url.host ?? "").lowercased()
        let path=url.path
        let cdnHosts=["xhscdn.com", "douyinpic.com", "byteimg.com", "douyinvod.com", "rednotecdn.com"]
        if cdnHosts.contains(where: { host.hasSuffix($0) }) {
            return path
        }

        // 其他站点：只剥掉确定易变的签名参数，其余保留（可能真在区分内容）
        let volatile: Set<String>=["x-expires", "x-signature", "x-bogus", "a_bogus", "expires", "ts", "token", "sig", "sign"]
        var components=URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let items=components?.queryItems {
            components?.queryItems=items.filter { !volatile.contains($0.name.lowercased()) }
        }
        return components?.string ?? url.absoluteString
    }

    /// 文件名用键的 SHA256：URL 里有 `?`、`/`、中文，直接当文件名在部分文件系统上会失败
    static func fileName(for key: String) -> String {
        let digest=SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".jpg"
    }

    private static let userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private static func cost(of image: PlatformImage) -> Int {
        #if os(macOS)
        return Int(image.size.width * image.size.height * 4)
        #else
        return Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        #endif
    }
}
