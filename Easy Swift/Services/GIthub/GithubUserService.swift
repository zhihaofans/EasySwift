//
//  GithubUserService.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import Alamofire
import Foundation
import SwiftUtils

class GithubUserService {
    private let http = HttpUtil()
    init() {
        let accessToken = GithubLoginService().getAccessToken()
        var headers: HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Referer": "https://www.github.com/",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        ]
        if accessToken.isNotEmpty {
            headers["Authorization"] = "Bearer \(accessToken)"
            headers["Accept"] = "application/vnd.github+json"
        }
        http.setHeader(headers)
    }

    func getStarsList(callback: @escaping ([GithubTrendingItem])->Void, fail: @escaping (GithubApiResultErrorModel)->Void) {
        let username = GithubLoginService().getUserName()
        let url = "https://api.github.com/users/\(username)/starred"
        print(url)
        http.get(url) { value in
            if value.isEmpty {
                fail(GithubApiResultErrorModel(message: "getStarsList.result.isEmpty", documentation_url: ""))
            } else {
//                print(value)
                do {
                    let result = try JSONDecoder().decode([GithubTrendingItem].self, from: value.data(using: .utf8)!)
//                    debugPrint(result.total_count)
                    callback(result)
                } catch {
                    print(error)
                    print("getStarsList.catch.error")
                    if value.contains("documentation_url") {
                        do {
                            let apiErrResult = try JSONDecoder().decode(GithubApiResultErrorModel.self, from: value.data(using: .utf8)!)
                            fail(apiErrResult)
                        } catch let err_ {
                            print(err_)
                            print("getStarsList.catch.error")
                            fail(GithubApiResultErrorModel(message: "getStarsList:\(err_)", documentation_url: ""))
                        }
                    } else {
                        fail(GithubApiResultErrorModel(message: "getStarsList:\(error)", documentation_url: ""))
                    }
                }
            }
        } fail: { error in
            print(error)
            print("getStarsList.http.error")
            fail(GithubApiResultErrorModel(message: "getStarsList.network:\(error)", documentation_url: ""))
        }
    }
}
