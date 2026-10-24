//
//  GithubTrendingService.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/15.
//

import Foundation
import SwiftUtils

class GithubTrendingService {
    private let http = HttpUtil()
    init() {
        let accessToken = GithubLoginService().getAccessToken()
        // SwiftUtils 0.0.26 已剥离 Alamofire：请求头改用纯 Foundation 字典
        var headers: [String: String] = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Referer": "https://www.github.com/",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        ]
        if accessToken.isNotEmpty {
            headers["Authorization"] = "Bearer \(accessToken)"
            headers["Accept"] = "application/vnd.github+json"
        }
        // 原先这里组装完 headers 就没有下文，trending 请求一直没带上 Token/UA
        http.setHeader(headers)
    }

    func getTrendingList(language: String = "Swift", sinceDate: String = "", callback: @escaping (GithubTrendingResult)->Void, fail: @escaping (String)->Void) {
        var query="q=language:\(language)"
        // 时间过滤：created:>{起始日期}（模拟官方 trending 的 since 语义）
        if sinceDate.isNotEmpty {
            query += "+created:>\(sinceDate)"
        }
        let url = "https://api.github.com/search/repositories?\(query)&sort=stars&order=desc"
        http.get(url) { value in
            if value.isEmpty {
                fail("getTrendingList.result.isEmpty")
            } else {
//                debugPrint(value)
                do {
                    let result = try JSONDecoder().decode(GithubTrendingResult.self, from: value.data(using: .utf8)!)
                    debugPrint("[GitHub] 趋势列表 total_count=\(result.total_count)")
                    callback(result)
                } catch {
                    debugPrint(error)
                    debugPrint("getTrendingList.catch.error")
                    fail("getTrendingList:\(error)")
                }
            }
        } fail: { error in
            debugPrint(error)
            debugPrint("getTrendingList.http.error")
            fail("网络请求错误:\(error)")
        }
    }
}
