//
//  TikhubHttp.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/15.
//

import Alamofire
import Foundation
import SwiftUtils

class TikhubHttp {
    private let http = HttpUtil()
    // private let host_global = "https://api.tikhub.io"
    private let host = "https://api.tikhub.dev"
    private var headers: HTTPHeaders = [
        "Authorization": "Bearer 9d8f4e3e-2f4c-4c7b-8f3a-6f4e5d7c8b9a",
        "Content-Type": "application/json",
        "User-Agent": "EasySwift/0.0.1",
    ]
    private let tokenKey = "tikhub_token"
    init() {
        let newToken = getToken()
        print("Tikhub token: \(newToken)")
        if newToken.isNotEmpty {
            headers.update(name: "Authorization", value: "Bearer \(newToken)")
            print("Using new token: \(newToken)")
        }
    }

    func getToken() -> String {
        return UserDefaultUtil().getString(key: tokenKey, defaultValue: "")
    }

    func setToken(_ newToken: String) {
        UserDefaultUtil().setString(key: tokenKey, value: newToken)
        headers.update(name: "Authorization", value: "Bearer \(newToken)")
        print("Token updated to: \(newToken)")
    }

    func removeToken() {
        UserDefaultUtil().remove(tokenKey)
        headers.update(name: "Authorization", value: "")
    }

    func getApiUrl(path: String) -> String {
        return host + path
    }

    /// 通用 GET 请求
    func get<T: Decodable>(
        path: String,
        parameters: [String: Any]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = getApiUrl(path: path)
        AF.request(url, method: .get, parameters: parameters, headers: headers)
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    /// 通用 POST 请求
    func post<T: Decodable>(
        path: String,
        parameters: [String: Any],
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = getApiUrl(path: path)
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
}
