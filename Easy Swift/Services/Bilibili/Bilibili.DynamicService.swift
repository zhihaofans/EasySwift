//
//  DynamicService.swift
//  Bili-Swift
//
//  Created by zzh on 2024/10/6.
//

import Alamofire
import Foundation
import SwiftUtils

class BiliDynamicService {
    private let http = HttpUtil()
//    private let headers: HTTPHeaders = [
//        "Cookie": "SESSDATA=" + BiliLoginService().getSESSDATA(),
//        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
//        // "Accept": "application/json;charset=UTF-8",
//    ]
    /// 基础 Header（必须带 SESSDATA 才能取到完整 feed）
    /// UA 取常见桌面浏览器，避免风控特判
    private var headers: HTTPHeaders {
        let sess = BiliLoginService().getSESSDATA()
        return [
            "Cookie": "SESSDATA=\(sess)",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://www.bilibili.com/"
        ]
    }

    /// 动态分类（文档中 `type` 参数）
    /// 说明：文档与实测中 `all` 默认即可；其他取值按需扩展
    enum FeedType: String {
        case all
        case video
        case pgc
        case article
        case live
        case music
        case bangumi
        // 可按需补充
    }

    /// 翻页游标（从响应 data 中取出，用于下次请求）
    struct Cursor {
        let offset: String?
        let updateBaseline: String?
        let page: Int?
    }

    private let baseURL = "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all"

    init() {
        http.setHeader(headers)
    }

    func getDynamicList(callback: @escaping (BiliDynamicListResult)->Void, fail: @escaping (String)->Void) {
        let url = "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all"
        http.get(url) { result in
            if result.isEmpty {
                fail("result.isEmpty")
            } else {
                // print(result)
                // print(result+"\n\n\n\n\n\n=======\n\n\n\n")
                do {
                    let data = try JSONDecoder().decode(BiliDynamicListResult.self, from: result.data(using: .utf8)!)
                    debugPrint(data.code)
                    if data.code == 0 {
//                        debugPrint(data.data)
                        callback(data)
                    } else {
                        fail("Code \(data.code): \(data.message)")
                    }
                } catch {
                    print(error)
                    print("getDynamicList.catch.error")
                    fail("getDynamicList:\(error.localizedDescription)")
                }
            }
        } fail: { error in
            print(error)
            print("getDynamicList.http.error")
            fail("getDynamicList:\(error)")
        }
    }

    // MARK: - Public APIs

    /// 获取动态列表（支持官方参数与翻页）
    ///
    /// - Parameters:
    ///   - type: 动态分类，默认 `all`
    ///   - offset: 上一页返回的 offset，用于向后翻页
    ///   - updateBaseline: 上一页返回的 update_baseline，用于增量刷新/翻页
    ///   - page: 页码（文档列出为可选；一般用 offset/ub 游标更稳）
    ///   - features: 功能开关，常见 `itemOpusStyle` 以启用新样式
    ///   - platform: 平台标识，默认 `web`
    ///   - timezoneOffsetMinutes: 时区偏移（分钟）。文档示例为 -480；我们按本地时区自动计算
    ///   - completion: 成功回调（返回解码后的结果与下一次请求所需游标）
    ///   - fail: 失败回调
    func getDynamicListV2(
        type: FeedType = .all,
        offset: String? = nil,
        updateBaseline: String? = nil,
        page: Int? = nil,
        features: [String] = ["itemOpusStyle"],
        platform: String = "web",
        timezoneOffsetMinutes: Int? = (TimeZone.current.secondsFromGMT() / 60),
        completion: @escaping (_ result: BiliDynamicListResult, _ cursor: Cursor)->Void,
        fail: @escaping (_ message: String)->Void
    ) {
        guard var comps = URLComponents(string: baseURL) else {
            fail("Invalid URL")
            return
        }

        var query: [URLQueryItem] = []
        query.append(URLQueryItem(name: "type", value: type.rawValue)) // all / video / article / ...
        if let offset = offset, !offset.isEmpty {
            query.append(URLQueryItem(name: "offset", value: offset)) // 翻页游标
        }
        if let ub = updateBaseline, !ub.isEmpty {
            query.append(URLQueryItem(name: "update_baseline", value: ub)) // 翻页/增量
        }
        if let page = page {
            query.append(URLQueryItem(name: "page", value: String(page))) // 可选
        }
        if !features.isEmpty {
            query.append(URLQueryItem(name: "features", value: features.joined(separator: ","))) // e.g. itemOpusStyle
        }
        query.append(URLQueryItem(name: "platform", value: platform)) // web（可选）
        if let tz = timezoneOffsetMinutes {
            query.append(URLQueryItem(name: "timezone_offset", value: String(tz))) // 文档出现过，单位：分钟
        }
        comps.queryItems = query

        guard let url = comps.url?.absoluteString else {
            fail("Invalid URLComponents")
            return
        }

        // 使用你现有的 HttpUtil 发 GET
        http.get(url) { [weak self] result in
            guard let _ = self else { return }
            if result.isEmpty {
                fail("Empty response")
                return
            }

            do {
                // 直接用你已有的模型进行解码
                let data = try JSONDecoder().decode(BiliDynamicListResult.self, from: Data(result.utf8))

                // B 站常见：code == 0 为成功；-352/其它为风控/异常
                guard data.code == 0 else {
                    fail("Code \(data.code): \(data.message)")
                    return
                }

                // 从 data 里把翻页游标抠出来（字段名以文档/实测为准）
                // 假定你的 `BiliDynamicListResult` 里存在 `data.offset` 和 `data.update_baseline`、可选的 `data.page`。
                // 如果你的模型字段名不同，请在此处按实际字段名取值。
                let nextCursor = Cursor(
                    offset: data.data?.offset ?? data.data?.items.last?.id_str, // 兜底：有些版本把 offset 放在 data 根上
                    updateBaseline: data.data?.update_baseline,
                    page: (data.data as AnyObject?)?["page"] as? Int // 如果模型没有 page，可忽略
                )

                completion(data, nextCursor)
            } catch {
                // 打印原始报文有助于排错（必要时可暂时打开）
                // print(result)
                fail("Decode error: \(error.localizedDescription)")
            }

        } fail: { error in
            // 网络/风控/限流等
            fail("HTTP error: \(error)")
        }
    }

    /// 解析“直播推荐”动态内容
    func getLiveDynamicContentV2(
        _ contentJson: String,
        callback: @escaping (BiliDynamicListItemModuleDynamicMajorLiveRcmdContent)->Void,
        fail: @escaping (String)->Void
    ) {
        do {
            let data = try JSONDecoder().decode(
                BiliDynamicListItemModuleDynamicMajorLiveRcmdContent.self,
                from: Data(contentJson.utf8)
            )
            callback(data)
        } catch {
            fail("Parse LiveRcmdContent error: \(error.localizedDescription)")
        }
    }

    func getLiveDynamicContent(_ contentJson: String, callback: @escaping (BiliDynamicListItemModuleDynamicMajorLiveRcmdContent)->Void, fail: @escaping (String)->Void) {
        do {
            let data = try JSONDecoder().decode(BiliDynamicListItemModuleDynamicMajorLiveRcmdContent.self, from: contentJson.data(using: .utf8)!)
            debugPrint(data)
            callback(data)
        } catch {
            print(error)
            print("DynamicListItemModuleDynamicMajorLiveRcmdContent")
            fail(error.localizedDescription)
        }
    }
}
