//
//  GithubTrendingService.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/15.
//

import Alamofire
import Foundation
import SwiftUtils

class GithubTrendingService {
    private let http = HttpUtil()
    private let headers: HTTPHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "https://www.github.com/",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    ]
    init() {
        http.setHeader(headers)
    }

    func getTrendingList(language: String = "Swift", callback: @escaping (GithubTrendingResult)->Void, fail: @escaping (String)->Void) {
        let url = "https://api.github.com/search/repositories?q=language:\(language)&sort=stars&order=desc"
        http.get(url) { value in
            if value.isEmpty {
                fail("getTrendingList.result.isEmpty")
            } else {
                print(value)
                do {
                    let result = try JSONDecoder().decode(GithubTrendingResult.self, from: value.data(using: .utf8)!)
                    debugPrint(result.total_count)

                    callback(result)
                } catch {
                    print(error)
                    print("getTrendingList.catch.error")
                    fail("getTrendingList:\(error)")
                }
            }
        } fail: { error in
            print(error)
            print("getTrendingList.http.error")
            fail("网络请求错误:\(error)")
        }
    }
}
