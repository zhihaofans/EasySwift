//
//  XiaohongshuSession.swift
//  Easy Swift
//
//  小红书登录态：cookie 存钥匙串，只有"行为探测"通过才算真的登录。
//
//  三条规矩：
//  1. 不能按 cookie 名判断登录 —— 网页端会先种一枚游客态的 web_session，按名字判会把未登录认成已登录；
//  2. cookie 不能落 UserDefaults —— 它是凭据，跟 GitHub Token 一个级别，走钥匙串；
//  3. "过期"和"从没登录"要分开 —— 前者该提示重新登录，后者该引导去登录，文案不同。
//

import Foundation
import SwiftUtils

/// 登录态。`unknown` = 还没探测过；`expired` = 有 cookie 但探测没过
enum XiaohongshuLoginState: String {
    case unknown
    case valid
    case expired
}

actor XiaohongshuSession {
    static let shared = XiaohongshuSession()

    /// 探测地址。
    /// **不能用 `/explore`**：游客态也有 web_session，未登录同样能打开信息流并返回 200，
    /// 用它探测等于把"能看首页"当成"已登录"。这里用只有登录态才进得去的消息页。
    private static let probeURL = URL(string: "https://www.xiaohongshu.com/notification")!
    private static let storageKey = "xhs_web_session_cookies"
    private static let stateKey = "xhs_session_state"
    private static let stateAtKey = "xhs_session_state_at"

    private let keychain = KeychainUtil()
    private let defaults = UserDefaults.standard

    // MARK: - 读取

    /// 拼成请求头用的 `name=value; name=value`
    func cookieHeader() -> String? {
        guard let raw = keychain.getString(forKey: Self.storageKey), !raw.isEmpty else { return nil }
        // 老版本存的是 JSON 数组（HTTPCookie 序列化），新版本统一存原始 header 串
        if raw.hasPrefix("[") {
            let header = Self.header(from: Self.deserialize(raw))
            if let header, !header.isEmpty {
                _ = keychain.saveString(forKey: Self.storageKey, value: header)
            }
            return header
        }
        return raw
    }

    var hasStoredCookie: Bool {
        return (keychain.getString(forKey: Self.storageKey)?.isEmpty == false)
    }

    /// 当前登录态。没有 cookie 一律 unknown（从没登录过）
    func state() -> XiaohongshuLoginState {
        guard hasStoredCookie else { return .unknown }
        return XiaohongshuLoginState(rawValue: defaults.string(forKey: Self.stateKey) ?? "") ?? .unknown
    }

    /// 上次探测时间，界面上可以显示"最近校验于…"
    func lastCheckedAt() -> Date? {
        let stamp = defaults.double(forKey: Self.stateAtKey)
        guard stamp > 0 else { return nil }
        return Date(timeIntervalSince1970: stamp)
    }

    // MARK: - 写入

    /// 网页登录拿到的 cookie：只留真正需要的几条，别把整站 cookie 塞进钥匙串
    @discardableResult
    func save(cookies: [HTTPCookie]) -> Bool {
        let kept = cookies.filter { Self.isRelevant($0) }
        guard !kept.isEmpty, let header = Self.header(from: kept) else { return false }
        // 只打名字不打值：这几个都是凭据。名字列表能回答"到底存进去了哪几条"
        debugPrint("[小红书] 保存 cookie: \(kept.map(\.name).sorted())")
        return save(header: header)
    }

    /// 直接保存一串 `name=value; name=value`（手动填写用）。
    /// - Important: 调用方应该先用 `validate(cookieHeader:)` 验过再存，否则等于存了一枚无效 cookie
    @discardableResult
    func save(header: String) -> Bool {
        guard !header.isEmpty else { return false }
        return keychain.saveString(forKey: Self.storageKey, value: header)
    }

    func clear() {
        _ = keychain.remove(forKey: Self.storageKey)
        setState(.unknown)
    }

    // MARK: - 探测与状态

    /// 探测结果三态。
    /// 只有 `.ok` 能证明"登录可用"；`.unavailable`（5xx/超时）**不能**当成过期，
    /// 否则平台一抖，用户的登录态就被误杀了
    enum ProbeResult {
        case ok
        case gated
        case unavailable
    }

    /// 用已存的 cookie 探一次并刷新状态
    @discardableResult
    func refreshState() async -> XiaohongshuLoginState {
        guard let header = cookieHeader() else {
            setState(.unknown)
            return .unknown
        }
        switch await probe(cookieHeader: header) {
        case .ok:
            setState(.valid)
            return .valid
        case .gated:
            setState(.expired)
            return .expired
        case .unavailable:
            // 平台暂时不可用：维持原状态，不因一次抖动把用户判成过期
            debugPrint("[小红书] 探测遇到 5xx/网络问题，状态保持不变: \(state().rawValue)")
            return state()
        }
    }

    /// 解析时撞到登录墙：只有原本判定为"已登录"的，才升级成"过期"。
    /// 从没登录过的不要被标记成过期，否则文案会误导用户。
    func noteLoginWall() {
        guard hasStoredCookie, state() == .valid else { return }
        debugPrint("[小红书] 解析撞到登录墙，把状态从 valid 改为 expired")
        setState(.expired)
    }

    /// 用给定 cookie 探一次
    func probe(cookieHeader: String) async -> ProbeResult {
        guard !cookieHeader.isEmpty else { return .gated }
        guard let response = try? await VideoHTTP.get(Self.probeURL,
                                                      ua: VideoHTTP.UA.desktopChrome,
                                                      cookies: cookieHeader)
        else {
            debugPrint("[小红书] 登录态探测请求失败（网络）")
            return .unavailable
        }
        let path = response.url.path.lowercased()
        let gated = path.contains("/login") || path.contains("website-login") || path.contains("captcha")
        debugPrint("[小红书] 登录态探测: status=\(response.status) final=\(response.url.absoluteString.prefix(80)) 登录墙=\(gated)")

        if gated { return .gated }
        switch response.status {
        case 200 ..< 300:
            // 200 也可能是"登录墙 + 200"：页面里出现扫码/验证码登录说明没真的登录成功。
            // （实测：平台限流时同一个无效 cookie 有时给 500、有时给 200，只看状态码不可靠）
            let body = response.body
            let looksLoggedOut = body.contains("扫码登录") || body.contains("验证码登录") || body.contains("登录后免费畅享")
            if looksLoggedOut {
                debugPrint("[小红书] 探测返回 200 但页面是登录墙，判为未登录")
                return .gated
            }
            return .ok
        case 401, 403:
            return .gated
        default:
            // 5xx：平台侧的临时问题（我们实测过未登录时也会给 500），不能据此判过期
            return .unavailable
        }
    }

    /// 布尔版本：只有确定可用才算 true
    func validate(cookieHeader: String) async -> Bool {
        return await probe(cookieHeader: cookieHeader) == .ok
    }

    // MARK: - 内部

    private func setState(_ state: XiaohongshuLoginState) {
        defaults.set(state.rawValue, forKey: Self.stateKey)
        defaults.set(Date().timeIntervalSince1970, forKey: Self.stateAtKey)
    }

    /// 只留小红书域名下的登录相关 cookie
    static func isRelevant(_ cookie: HTTPCookie) -> Bool {
        guard cookie.domain.contains("xiaohongshu.com") else { return false }
        let name = cookie.name.lowercased()
        // id_token：扫码登录后才出现（JWT 形态），做搜索/API 那条线要用到。
        // 它是凭据，所以和 web_session 一样只进钥匙串，不进日志、不进 UserDefaults。
        return ["web_session", "a1", "webid", "gid", "xsecappid", "customerclientid", "id_token"].contains(name)
    }

    /// 拼成 Cookie 请求头
    static func header(from cookies: [HTTPCookie]) -> String? {
        let pairs = cookies.map { "\($0.name)=\($0.value)" }
        guard !pairs.isEmpty else { return nil }
        return pairs.joined(separator: "; ")
    }

    /// 清洗手动粘贴进来的 cookie 串：去掉 `Cookie:` 前缀、换行、多余分号
    static func sanitize(header raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("cookie:") {
            text = String(text.dropFirst("cookie:".count))
        }
        // 换行当分隔符用（从 DevTools 复制常带换行）
        text = text.replacingOccurrences(of: "\r", with: ";")
            .replacingOccurrences(of: "\n", with: ";")
        let parts = text.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.contains("=") }
        return parts.joined(separator: "; ")
    }

    /// 从 header 里取某个 cookie 的值（调试与校验用）
    static func value(of name: String, in header: String) -> String? {
        for part in header.split(separator: ";") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard let equal = piece.firstIndex(of: "=") else { continue }
            if piece[..<equal].trimmingCharacters(in: .whitespaces) == name {
                return String(piece[piece.index(after: equal)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// 老格式（JSON 数组）解析，只用于迁移
    static func deserialize(_ raw: String) -> [HTTPCookie] {
        guard let data = raw.data(using: .utf8),
              let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return [] }

        return items.compactMap { item in
            guard let name = item["name"] as? String,
                  let value = item["value"] as? String,
                  let domain = item["domain"] as? String
            else { return nil }
            var properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: domain,
                .path: item["path"] as? String ?? "/",
            ]
            if let expires = item["expires"] as? TimeInterval {
                properties[.expires] = Date(timeIntervalSince1970: expires)
            }
            return HTTPCookie(properties: properties)
        }
    }
}
