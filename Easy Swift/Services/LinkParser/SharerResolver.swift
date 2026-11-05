//
//  SharerResolver.swift
//  Easy Swift
//
//  从**分享链接**里解出「分享者」账号 —— 也就是把这条链接转发出来的人，不是内容作者。
//
//  为什么两者不同：平台在分享链接里埋了转发者的标识（用于社交关系追踪），
//  所以拿到一条别人分享的链接，就能知道是谁分享的。两个平台的实现完全不同：
//
//  - 抖音：短链展开后的长链 query 里带 `u_code`（base-23 编码的 uid）、`share_user_id`、
//    也可能把 uid 塞在 `activity_info` / `share_extra_params` 的 JSON 里；
//    uid 拿到后可以再查 `live.douyin.com/webcast/user` 换昵称与 sec_uid（该接口可能随时失效）。
//  - 小红书：query 里带 `shareRedId`（32 位 Base64URL → 24 字节，逐字节减固定偏移表 → 24 位十六进制 uid）。
//    **纯离线**，不发任何请求。
//
//  算法来源（第三方公开分析）：cnlnn《share-link identity tracking》与 isarvin 的小红书 shareRedId 文章。
//  这里只做「一条链接 → 一个账号」，不枚举、不批量查询。
//

import Foundation

/// 分享者信息
struct LinkSharer: Equatable {
    enum Platform: String {
        case douyin
        case rednote

        var title: String {
            switch self {
            case .douyin: return "抖音"
            case .rednote: return "小红书"
            }
        }
    }

    let platform: Platform
    /// 平台内部账号 ID（抖音是数字 uid，小红书是 24 位十六进制 uid）
    let accountID: String
    var nickname: String?
    /// 抖音专有：主页地址用的是 sec_uid
    var secUID: String?
    var profileURL: URL?

    /// 界面上显示的名字：优先昵称，否则退化到账号 ID
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return accountID
    }
}

enum SharerResolver {
    // MARK: - 小红书（纯离线）

    /// `shareRedId` 的逐字节偏移表（长度固定 24，与解码后的 24 字节一一对应）
    private static let rednoteOffsets: [UInt8]=[
        2, 6, 2, 0, 3, 5, 4, 9, 6, 7, 5, 2,
        9, 8, 0, 6, 6, 3, 9, 7, 4, 5, 6, 9,
    ]

    /// 从小红书主页 HTML 的 `__INITIAL_STATE__` 里取昵称。
    /// 三种结构都见过：`user.userPageData.userInfo`、`user.userInfo`、`profile.userInfo`
    static func rednoteNickname(fromState state: [String: Any]) -> String? {
        let containers: [[String: Any]]=[state["user"], state["profile"]].compactMap { $0 as? [String: Any] }
        for container in containers {
            if let pageData=container["userPageData"] as? [String: Any],
               let info=pageData["userInfo"] as? [String: Any],
               let nickname=stringValue(info["nickname"])
            {
                return nickname
            }
            if let info=container["userInfo"] as? [String: Any], let nickname=stringValue(info["nickname"]) {
                return nickname
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let text=value as? String else { return nil }
        let trimmed=text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "null" ? nil : trimmed
    }

    /// 尽力而为：用 App 里的登录态抓一次主页，取分享者昵称。
    /// 失败（风控/未登录/结构变化）就返回 nil，界面回落显示账号 ID，不算错误。
    static func rednoteNickname(uid: String, cookieHeader: String?) async -> String? {
        guard let url=URL(string: "https://www.xiaohongshu.com/user/profile/\(uid)") else { return nil }
        do {
            let response=try await VideoHTTP.get(url, ua: VideoHTTP.UA.iOSSafari, headers: [
                "Origin": "https://www.xiaohongshu.com",
            ], cookies: cookieHeader)
            let path=response.url.path.lowercased()
            if path.contains("login") || path.contains("website-login") {
                debugPrint("[分享者] 小红书取昵称撞登录墙/风控，回落显示 ID")
                return nil
            }
            guard let state=XiaohongshuParser.parseInitialState(from: response.body) else {
                debugPrint("[分享者] 小红书主页没有 __INITIAL_STATE__，回落显示 ID")
                return nil
            }
            if let nickname=rednoteNickname(fromState: state) {
                debugPrint("[分享者] 小红书昵称取到（\(nickname.count) 字）")
                return nickname
            }
            debugPrint("[分享者] 小红书主页里没找到 nickname，回落显示 ID")
            return nil
        } catch {
            debugPrint("[分享者] 小红书取昵称失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从链接的 `shareRedId` 解出小红书 uid；没有该参数或格式不符返回 nil
    static func rednote(from url: URL) -> LinkSharer? {
        #if DEBUG
        // 测试钩子：没有网络/链接时也能验解码，见 harness
        #endif
        guard let components=URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let token=components.queryItems?.first(where: { $0.name == "shareRedId" })?.value else { return nil }
        guard let uid=rednoteAccountID(fromShareRedID: token) else {
            debugPrint("[分享者] 小红书 shareRedId 解码失败，长度=\(token.count)")
            return nil
        }
        return LinkSharer(platform: .rednote,
                          accountID: uid,
                          nickname: nil,
                          secUID: nil,
                          profileURL: URL(string: "https://www.xiaohongshu.com/user/profile/\(uid)"))
    }

    /// 32 位 Base64URL → 24 字节 → 逐字节减偏移 → 必须是 24 位十六进制
    static func rednoteAccountID(fromShareRedID token: String) -> String? {
        guard token.count == 32, token.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        // Base64URL → Base64
        var base64=token.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let raw=Data(base64Encoded: base64), raw.count == 24 else { return nil }

        var recovered=[UInt8]()
        recovered.reserveCapacity(24)
        for (index, byte) in raw.enumerated() {
            recovered.append(byte &- rednoteOffsets[index])
        }
        let text=String(decoding: recovered, as: UTF8.self)
        guard text.count == 24, text.allSatisfy({ $0.isHexDigit }) else { return nil }
        return text.lowercased()
    }

    // MARK: - 抖音

    /// Base-23 字母表：0-9 之后是 a-m
    private static let douyinAlphabet=Array("0123456789abcdefghijklm")

    /// u_code（base-23）→ 十进制 uid
    static func douyinDecodeUCode(_ code: String) -> String? {
        guard !code.isEmpty else { return nil }
        var value=0
        for character in code.lowercased() {
            guard let digit=douyinAlphabet.firstIndex(of: character) else { return nil }
            value = value * 23 + digit
        }
        return String(value)
    }

    /// 十进制 uid → u_code（round-trip 自检用）
    static func douyinEncodeUID(_ uid: String) -> String? {
        guard let number=UInt64(uid) else { return nil }
        if number == 0 { return "0" }
        var remaining=number
        var out=""
        while remaining > 0 {
            let digit=Int(remaining % 23)
            remaining /= 23
            out=String(douyinAlphabet[digit]) + out
        }
        return out
    }

    /// 直接从链接 query 里拿分享者 uid 与 sec_uid（不需要请求）
    static func douyinIdentity(from url: URL) -> (accountID: String?, secUID: String?) {
        guard let components=URLComponents(url: url, resolvingAgainstBaseURL: false) else { return (nil, nil) }
        let items=components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        var accountID: String?
        // 1) u_code 优先（能直接解成 uid）
        if let code=value("u_code"), let decoded=douyinDecodeUCode(code) {
            accountID=decoded
        }
        // 2) 链接里直接给了 share_user_id
        if accountID == nil, let raw=value("share_user_id") ?? value("social_share_user_id"),
           raw.allSatisfy({ $0.isNumber }), !raw.isEmpty
        {
            accountID=raw
        }
        // 3) activity_info / share_extra_params 是 URL 编码的 JSON，里面可能带 social_share_user_id
        if accountID == nil {
            for key in ["activity_info", "share_extra_params", "ecom_share_track_params"] {
                guard let json=value(key) else { continue }
                if let extracted=douyinShareUserID(inJSON: json) {
                    accountID=extracted
                    break
                }
            }
        }

        let secUID=value("sec_uid") ?? value("sec_relation_user_id")
        return (accountID, secUID)
    }

    /// 从（URL 编码的）JSON 字符串里抠 share_user_id / social_share_user_id
    private static func douyinShareUserID(inJSON raw: String) -> String? {
        var text=raw
        if let decoded=text.removingPercentEncoding { text=decoded }
        guard let data=text.data(using: .utf8),
              let object=(try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        for key in ["social_share_user_id", "share_user_id"] {
            if let value=object[key] as? String, value.allSatisfy({ $0.isNumber }), !value.isEmpty {
                return value
            }
            if let number=object[key] as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    /// 走 `live.douyin.com/webcast/user` 换昵称与 sec_uid。
    /// 该接口是公开 web 接口，**可能随时失效**，失败只是少显示昵称，不影响解析主流程。
    static func douyinLookup(uid: String) async -> (nickname: String?, secUID: String?) {
        guard let url=URL(string: "https://live.douyin.com/webcast/user/?aid=6383&target_uid=\(uid)") else {
            return (nil, nil)
        }
        do {
            let response=try await VideoHTTP.get(url, ua: VideoHTTP.UA.iOSSafari, headers: [
                "Referer": "https://live.douyin.com/",
            ])
            guard let data=response.body.data(using: .utf8),
                  let payload=(try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let info=payload["data"] as? [String: Any]
            else {
                debugPrint("[分享者] 抖音 webcast 返回结构不认识，HTTP \(response.status)")
                return (nil, nil)
            }
            let nickname=(info["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let secUID=info["sec_uid"] as? String
            debugPrint("[分享者] 抖音 webcast 查询成功：nickname=\(nickname?.isEmpty == false ? "有" : "无") sec_uid=\(secUID?.isEmpty == false ? "有" : "无")")
            return (nickname?.isEmpty == false ? nickname : nil, (secUID?.isEmpty == false) ? secUID : nil)
        } catch {
            debugPrint("[分享者] 抖音 webcast 查询失败: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    /// 抖音分享者完整解析：先离线解 uid/sec_uid，需要昵称时再查一次接口
    static func douyin(from url: URL, lookup: Bool) async -> LinkSharer? {
        let identity=douyinIdentity(from: url)
        var accountID=identity.accountID
        var secUID=identity.secUID
        var nickname: String?

        if accountID == nil, secUID != nil {
            // 只有 sec_uid 时也能拼主页，账号 ID 就先用 sec_uid 顶上
            accountID=secUID
        }
        guard let resolvedID=accountID else { return nil }

        if lookup, identity.accountID != nil {
            let info=await douyinLookup(uid: resolvedID)
            nickname=info.nickname
            if let lookedUpSec=info.secUID { secUID=lookedUpSec }
        }

        let profileURL=secUID.flatMap { URL(string: "https://www.douyin.com/user/\($0)") }
            // 没有 sec_uid 时至少给一个能用 uid 打开的主页入口
            ?? URL(string: "https://www.douyin.com/user/self?modal_id=&target_uid=\(resolvedID)")
        return LinkSharer(platform: .douyin,
                          accountID: resolvedID,
                          nickname: nickname,
                          secUID: secUID,
                          profileURL: profileURL)
    }
}
