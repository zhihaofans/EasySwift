//
//  XiaohongshuSession.swift
//  Easy Swift
//
//  小红书登录态：cookie 存钥匙串，只有"行为探测"通过才算真的登录。
//
//  两个坑：
//  1. 不能按 cookie 名判断登录 —— 网页端会先种一枚游客态的 web_session，按名字判会把未登录认成已登录；
//  2. cookie 不能落 UserDefaults —— 它是凭据，跟 GitHub Token 一个级别，走钥匙串。
//

import Foundation
import SwiftUtils

actor XiaohongshuSession {
    static let shared = XiaohongshuSession()

    /// 探测地址：登录态会看到信息流，未登录会被 302 到 /login
    private static let probeURL = URL(string: "https://www.xiaohongshu.com/explore")!
    private static let storageKey = "xhs_web_session_cookies"

    private let keychain = KeychainUtil()

    // MARK: - 读取

    /// 拼成请求头用的 `name=value; name=value`
    func cookieHeader() -> String? {
        guard let raw = keychain.getString(forKey: Self.storageKey), !raw.isEmpty else { return nil }
        return Self.header(from: Self.deserialize(raw))
    }

    var hasStoredCookie: Bool {
        return (keychain.getString(forKey: Self.storageKey)?.isEmpty == false)
    }

    // MARK: - 写入

    /// 只保存真正需要的几条，别把整站 cookie 塞进钥匙串
    @discardableResult
    func save(cookies: [HTTPCookie]) -> Bool {
        let kept = cookies.filter { Self.isRelevant($0) }
        guard !kept.isEmpty else { return false }
        let payload = Self.serialize(kept)
        return keychain.saveString(forKey: Self.storageKey, value: payload)
    }

    func clear() {
        _ = keychain.remove(forKey: Self.storageKey)
    }

    // MARK: - 行为探测

    /// 用已存的 cookie 探一次；没有 cookie 直接 false
    func validate() async -> Bool {
        guard let header = cookieHeader() else { return false }
        return await validate(cookieHeader: header)
    }

    /// 用给定 cookie 探一次：被重定向到登录页/验证页就说明没登录
    func validate(cookieHeader: String) async -> Bool {
        guard !cookieHeader.isEmpty else { return false }
        guard let response = try? await VideoHTTP.get(Self.probeURL,
                                                      ua: VideoHTTP.UA.desktopChrome,
                                                      cookies: cookieHeader)
        else {
            debugPrint("[小红书] 登录态探测请求失败")
            return false
        }
        let path = response.url.path.lowercased()
        let gated = path.contains("/login") || path.contains("website-login") || path.contains("captcha")
        // 只看"有没有被踢到登录页"不够：未登录时服务端也可能给 500/403 而地址不变，
        // 那种情况必须判为未登录，否则会拿一枚无效 cookie 假装已登录
        let healthy = (200 ..< 300).contains(response.status)
        debugPrint("[小红书] 登录态探测: status=\(response.status) final=\(response.url.absoluteString.prefix(80)) 登录墙=\(gated) 正常=\(healthy)")
        return healthy && !gated
    }

    // MARK: - 序列化与筛选

    /// 只留小红书域名下的登录相关 cookie
    static func isRelevant(_ cookie: HTTPCookie) -> Bool {
        guard cookie.domain.contains("xiaohongshu.com") else { return false }
        let name = cookie.name.lowercased()
        return ["web_session", "a1", "webid", "gid", "xsecappid", "customerclientid"].contains(name)
    }

    /// 拼成 Cookie 请求头
    static func header(from cookies: [HTTPCookie]) -> String? {
        let pairs = cookies.map { "\($0.name)=\($0.value)" }
        guard !pairs.isEmpty else { return nil }
        return pairs.joined(separator: "; ")
    }

    /// JSON 里只存必要字段，避免依赖 HTTPCookie 的属性持久化行为
    static func serialize(_ cookies: [HTTPCookie]) -> String {
        let items: [[String: Any]] = cookies.map { cookie in
            var item: [String: Any] = [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
            ]
            if let expires = cookie.expiresDate {
                item["expires"] = expires.timeIntervalSince1970
            }
            return item
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

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
