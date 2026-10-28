//
//  XiaohongshuParser.swift
//  Easy Swift
//
//  小红书解析：纯 HTTP，抠笔记页内嵌的 __INITIAL_STATE__。
//
//  这套口径来自真机实测，改之前先看清楚为什么这么写：
//  - 分享链接 `?` 之后的查询串（xsec_token）必须原样带上，缺了就落到 /404 风控页；
//  - 判定一律看重定向后的 finalURL，不要按入参 URL 猜（explore 会被服务端 302 到 discovery）；
//  - 未登录也可能拿到内容，但风控是概率性的，同一链接换个时刻就可能是登录墙 —— 所以失败要重试一次；
//  - 图文和视频、动图混在一起：图片走 imageList，视频走 video.media.stream，动图挂在单张图的 stream 上。
//
//  Created by zzh on 2026/08/20.
//

import Foundation

struct XiaohongshuParser: LinkParser {
    var name: String {
        "小红书"
    }

    /// 支持的链接：主站笔记页 + App 分享短链（短链会 302 到笔记页）
    private static let supportedHosts = ["xiaohongshu.com", "xhslink.com", "xhslink.cn"]

    /// 去水印原图 CDN
    private static let imageCDN = "https://sns-img-bd.xhscdn.com/"
    /// 视频流的清晰度优先级：越靠前越优先
    private static let videoCodecPriority = ["h265", "h264", "av1", "h266"]

    func canParse(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return Self.supportedHosts.contains(bare)
    }

    func parse(url: URL, progress: LinkParseProgress) async throws -> LinkParseResult {
        // 1. 短链先展开，拿到带 xsec_token 的真实地址
        let pageURL = try await expandIfNeeded(url, progress: progress)
        debugPrint("[小红书] 展开后: \(pageURL.absoluteString)")

        // 2. 抓页面：先用 iOS UA；命中登录墙再换桌面 UA 重试一次（风控是概率性的）
        progress(.requestingPage)
        var response = try await fetch(pageURL, ua: VideoHTTP.UA.iOSSafari)
        if Self.isLoginWall(response) {
            debugPrint("[小红书] iOS UA 命中登录墙，换桌面 UA 重试")
            progress(.retryingWithDesktopUA)
            response = try await fetch(pageURL, ua: VideoHTTP.UA.desktopChrome)
        }
        if Self.isLoginWall(response) {
            // `/website-login/error` + `error_code=300011` 是**安全限制**（分享链接缺 xsec_token
            // 时就会这样），不是登录过期 —— 错报"登录已过期"会让人白白重新扫码
            if Self.isSecurityBlock(response) {
                debugPrint("[小红书] 命中安全限制（缺 token），finalURL=\(response.url.absoluteString)")
                throw LinkParseError.unknown("这条笔记的分享链接不完整（缺少访问参数），请重新复制分享链接")
            }
            // 原本判定为"已登录"却撞墙 → 升级成"过期"，界面上要区分这两种情况
            await XiaohongshuSession.shared.noteLoginWall()
            throw LinkParseError.needLogin
        }
        if Self.isGone(response) {
            // 落 /404/sec_* 说明是被风控/令牌校验挡下来的，跟"作品确实删了"不是一回事；
            // 用户能操作的是"重新复制分享链接"
            let query = response.url.query ?? ""
            if response.url.path.lowercased().contains("/sec_") || !query.contains("xsec_token") {
                throw LinkParseError.unknown("笔记打不开：可能已删除或设为私密，也可能是分享链接已过期——请重新复制分享链接再试")
            }
            throw LinkParseError.notFound
        }

        // 3. 抠 __INITIAL_STATE__
        guard let state = Self.parseInitialState(from: response.body) else {
            debugPrint("[小红书] 页面里没有 __INITIAL_STATE__，finalURL=\(response.url.absoluteString)，长度=\(response.body.count)")
            throw LinkParseError.unknown("页面里没有笔记数据（可能被风控拦截），请稍后重试")
        }
        let noteID = Self.noteID(from: response.url) ?? Self.noteID(from: pageURL)
        guard let note = Self.noteObject(in: state, noteID: noteID) else {
            debugPrint("[小红书] __INITIAL_STATE__ 里找不到笔记对象，noteID=\(noteID ?? "nil")，顶层键=\(state.keys.sorted())")
            throw LinkParseError.unknown("笔记数据结构变了，暂时解析不出内容")
        }

        // 4. 视频笔记：有 video 字段就必须拿到直链，取不到要报错（不能拿封面顶替）
        if note["video"] != nil {
            guard let videoURL = Self.videoURL(from: note) else {
                throw LinkParseError.unknown("这条笔记带视频，但没取到视频直链（可能是平台改了流结构）")
            }
            let result=LinkParseResult(title: Self.title(from: note), videos: [videoURL.httpsURL])
            Self.logSuccess(result, kind: "视频笔记")
            return result
        }

        // 5. 图文：图片 + 动图（去水印要逐张 HEAD 探测，18 张会有一两秒）
        progress(.checkingOriginalImages)
        let media = await Self.images(from: note)
        guard !media.images.isEmpty else {
            throw LinkParseError.emptyResult
        }
        let result=LinkParseResult(title: Self.title(from: note),
                                   images: media.images,
                                   motions: media.motions,
                                   notice: media.notice)
        Self.logSuccess(result, kind: "图文笔记")
        return result
    }

    /// 成功日志：没有这一行的话，"解析出几张图"只能靠界面看，日志里断在 GET 那行
    static func logSuccess(_ result: LinkParseResult, kind: String) {
        debugPrint("[小红书] 解析成功(\(kind)): 标题=\(result.title ?? "nil") 图=\(result.images.count) 动图=\(result.motions.count) 视频=\(result.videos.count) notice=\(result.notice ?? "无")")
    }

    // MARK: - 请求

    /// 短链展开；本身就是笔记页时原样返回（**保留查询串**）
    private func expandIfNeeded(_ url: URL, progress: LinkParseProgress) async throws -> URL {
        guard let host = url.host, host.contains("xhslink") else { return url }
        progress(.expandingShortLink)
        return try await VideoHTTP.expandShortLink(url, ua: VideoHTTP.UA.iOSSafari)
    }

    private func fetch(_ url: URL, ua: String) async throws -> VideoHTTP.Response {
        // 有登录态就带上：私密笔记、以及部分被风控降级的页面只有带 cookie 才给数据
        let cookies=await XiaohongshuSession.shared.cookieHeader()
        debugPrint("[小红书] 登录态: \(cookies == nil ? "无" : "有")")
        do {
            return try await VideoHTTP.get(url, ua: ua, headers: [
                "Origin": "https://www.xiaohongshu.com",
                "X-Requested-With": "XMLHttpRequest",
            ], cookies: cookies)
        } catch let error as LinkParseError {
            throw error
        } catch {
            throw LinkParseError.network
        }
    }

    /// 登录墙：只看最终地址。不能靠"页面里没数据"反推——那是页面改版的样子
    static func isLoginWall(_ response: VideoHTTP.Response) -> Bool {
        let path = response.url.path.lowercased()
        return path.contains("/login") || path.contains("website-login") || path.contains("captcha")
    }

    /// 安全限制页：`/website-login/error` 且带 `error_code=300011`（缺 xsec_token 时出现）
    static func isSecurityBlock(_ response: VideoHTTP.Response) -> Bool {
        if response.url.path.lowercased().contains("website-login/error") { return true }
        if response.url.query?.contains("error_code=300011") == true { return true }
        return response.body.contains("300011")
    }

    /// 作品不可见：风控 404 页（200 状态 + 跳 /404），或页面带 300031
    static func isGone(_ response: VideoHTTP.Response) -> Bool {
        if response.url.path.lowercased().contains("/404") { return true }
        if response.status == 404 || response.status == 410 { return true }
        return response.body.contains("300031")
    }

    // MARK: - 内嵌 JSON

    /// 从 HTML 抠出 `window.__INITIAL_STATE__`。
    /// 服务端会输出裸 `undefined`（JS 字面量，不是合法 JSON），必须先整体换成 `null`。
    static func parseInitialState(from html: String) -> [String: Any]? {
        guard let marker = html.range(of: "__INITIAL_STATE__") else { return nil }
        guard let equal = html[marker.upperBound...].firstIndex(of: "=") else { return nil }
        let bodyStart = html.index(after: equal)
        guard let end = html[bodyStart...].range(of: "</script>") else { return nil }

        var raw = String(html[bodyStart ..< end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasSuffix(";") {
            raw.removeLast()
        }
        let cleaned = raw.replacingOccurrences(of: "undefined", with: "null")
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? [String: Any]
    }

    /// 笔记对象。
    /// discovery/item 走 `noteData.data.noteData`；explore 走 `note.noteDetailMap[<id>].note`
    static func noteObject(in state: [String: Any], noteID: String?) -> [String: Any]? {
        if let noteData = state["noteData"] as? [String: Any],
           let data = noteData["data"] as? [String: Any],
           let note = data["noteData"] as? [String: Any],
           !note.isEmpty
        {
            return note
        }
        if let note = state["note"] as? [String: Any],
           let map = note["noteDetailMap"] as? [String: Any]
        {
            if let id = noteID, let entry = map[id] as? [String: Any], let detail = entry["note"] as? [String: Any] {
                return detail
            }
            // 拿不到 id 时退回第一个带 note 的条目
            for value in map.values {
                if let entry = value as? [String: Any], let detail = entry["note"] as? [String: Any] {
                    return detail
                }
            }
        }
        return nil
    }

    // MARK: - 字段

    static func noteID(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let marker = parts.firstIndex(where: { $0 == "explore" || $0 == "item" }) else { return nil }
        let next = marker + 1
        guard next < parts.count else { return nil }
        let candidate = parts[next]
        return candidate.count >= 16 ? candidate : nil
    }

    static func title(from note: [String: Any]) -> String? {
        if let title = note["title"] as? String, !title.isEmpty {
            return title
        }
        // 图文笔记常常没有 title，用正文首行兜底
        guard let desc = note["desc"] as? String, !desc.isEmpty else { return nil }
        let firstLine = desc.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? desc
        return firstLine.isEmpty ? nil : String(firstLine.prefix(60))
    }

    /// 视频直链：按清晰度优先级取第一个 masterUrl（兼容 master_url）
    static func videoURL(from note: [String: Any]) -> URL? {
        guard let video = note["video"] as? [String: Any] else { return nil }
        let media = video["media"] as? [String: Any] ?? video
        guard let stream = media["stream"] as? [String: Any] else { return nil }

        for codec in videoCodecPriority {
            guard let candidates = stream[codec] as? [[String: Any]] else { continue }
            for candidate in candidates {
                if let raw = (candidate["masterUrl"] as? String) ?? (candidate["master_url"] as? String),
                   let url = URL(string: raw)
                {
                    return url
                }
            }
        }
        return nil
    }

    // MARK: - 图片（含去水印与动图）

    struct ImageMedia {
        var images: [URL] = []
        var motions: [Int: URL] = [:]
        var notice: String?
    }

    static func images(from note: [String: Any]) async -> ImageMedia {
        guard let list = note["imageList"] as? [[String: Any]] else { return ImageMedia() }

        var result = ImageMedia()
        var pending: [(index: Int, original: URL, probe: URL)] = []

        for (index, item) in list.enumerated() {
            guard let original = originalImageURL(from: item) else { continue }
            if let probe = dewatermarkURL(from: item, original: original) {
                pending.append((index: index, original: original.httpsURL, probe: probe))
                result.images.append(probe) // 先按去水印地址占位，探测失败再换回原图
            } else {
                result.images.append(original.httpsURL)
            }
            // 动图：单张图上挂的短视频
            if let motion = motionURL(from: item) {
                result.motions[index] = motion.httpsURL
            }
        }

        // 并发探测去水印地址：只有 404/410 才算"图没了"，
        // 超时 / 405（不支持 HEAD）都按可用处理——否则用户白拿带水印图
        let unavailable = await withTaskGroup(of: Int?.self) { group in
            for item in pending {
                group.addTask {
                    let code = await VideoHTTP.head(item.probe,
                                                    headers: ["Referer": "https://www.xiaohongshu.com/"])
                    guard let code, code == 404 || code == 410 else { return nil }
                    return item.index
                }
            }
            var indexes: [Int] = []
            for await index in group {
                if let index { indexes.append(index) }
            }
            return indexes
        }

        if !unavailable.isEmpty {
            for index in unavailable where index < result.images.count {
                if let original = pending.first(where: { $0.index == index })?.original {
                    result.images[index] = original
                }
            }
            result.notice = "\(unavailable.count) 张图片没有可用的去水印原图，已改用平台地址（可能带水印）"
        }
        return result
    }

    /// 原图地址：discovery 用 `url`，explore 用 `urlDefault`，再兜底 infoList
    static func originalImageURL(from item: [String: Any]) -> URL? {
        var candidates: [String] = []
        if let value = item["urlDefault"] as? String { candidates.append(value) }
        if let value = item["url"] as? String { candidates.append(value) }
        if let infoList = item["infoList"] as? [[String: Any]] {
            for info in infoList {
                if let value = info["url"] as? String { candidates.append(value) }
            }
        }
        for raw in candidates {
            if let url = URL(string: raw), url.scheme != nil {
                return url
            }
        }
        return nil
    }

    /// 去水印地址。
    /// 优先用 `fileId` 直接拼；没有 fileId 时按路径规则换算：
    /// 丢掉 host 之后的前两段（时间戳桶 + 散列），再截掉 `!` 之后的规格串。
    static func dewatermarkURL(from item: [String: Any], original: URL) -> URL? {
        if let fileID = item["fileId"] as? String, !fileID.isEmpty {
            return URL(string: imageCDN + fileID)
        }
        guard var path = original.path.removingPercentEncoding, path.hasPrefix("/") else { return nil }
        path.removeFirst()
        if let bangIndex = path.firstIndex(of: "!") {
            path = String(path[..<bangIndex])
        }
        let segments = path.split(separator: "/").map(String.init)
        guard segments.count > 2 else { return nil }
        let imagePath = segments.dropFirst(2).joined(separator: "/")
        guard !imagePath.isEmpty else { return nil }
        return URL(string: imageCDN + imagePath)
    }

    /// 动图：单张图上的 `stream`（h264/h265…）里取第一个可用视频
    static func motionURL(from item: [String: Any]) -> URL? {
        guard let stream = item["stream"] as? [String: Any] else { return nil }
        for codec in videoCodecPriority {
            guard let candidates = stream[codec] as? [[String: Any]] else { continue }
            for candidate in candidates {
                if let raw = (candidate["masterUrl"] as? String) ?? (candidate["master_url"] as? String),
                   let url = URL(string: raw)
                {
                    return url
                }
            }
        }
        return nil
    }
}
