//
//  TikhubHttp.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/15.
//

import Alamofire
import Foundation
import SwiftUtils

struct ApiWrapper<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

class TikhubHttpService {
    private let http = HttpUtil()
    // private let host_global = "https://api.tikhub.io"
    private let host = "https://api.tikhub.dev"
    private var headers: HTTPHeaders = [
        "Authorization": "Bearer 9d8f4e3e-2f4c-4c7b-8f3a-6f4e5d7c8b9a",
        "Content-Type": "application/json",
        "User-Agent": "EasySwift/0.0.1"
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

    /// 传统 completion 回调版（保留向后兼容）
    func get<T: Decodable>(
        path: String,
        parameters: [String: Any]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let urlString = getApiUrl(path: path)
        // 构建 URLRequest 以便可以设置 timeout / headers 等（更灵活）
        var urlComponents = URLComponents(string: urlString)
        if let params = parameters, !params.isEmpty {
            // 把 parameters 转成 query items（GET 场景）
            urlComponents?.queryItems = params.map { k, v in
                URLQueryItem(name: k, value: "\(v)")
            }
        }

        guard let url = urlComponents?.url else {
            completion(.failure(NSError(domain: "TikhubHttpService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])))
            return
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.httpMethod = "GET"
        // 把当前 headers 转为字典并设置到 URLRequest（确保最新 token 被使用）
        for header in headers {
            req.setValue(header.value, forHTTPHeaderField: header.name)
        }

        AF.request(req)
            .validate() // 默认校验 200...299
            .responseData { response in
                switch response.result {
                case .failure(let afError):
                    // 获取 HTTP 状态码 / body 以便调试
                    let code = response.response?.statusCode ?? -1
                    let bodyText = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
                    let errInfo: [String: Any] = [
                        NSLocalizedDescriptionKey: "Network error: \(afError.localizedDescription)",
                        "statusCode": code,
                        "body": bodyText
                    ]
                    completion(.failure(NSError(domain: "TikhubHttpService", code: code, userInfo: errInfo)))
                case .success(let data):
                    let decoder = JSONDecoder()
                    // 如果你的 model 使用 snake_case，请保留；否则移除或改为你项目一致的策略
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    do {
                        let obj = try decoder.decode(T.self, from: data)
                        completion(.success(obj))
                    } catch {
                        let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                        let errInfo: [String: Any] = [
                            NSLocalizedDescriptionKey: "JSON decode error: \(error.localizedDescription)",
                            "rawResponse": raw
                        ]
                        completion(.failure(NSError(domain: "TikhubHttpService", code: -2, userInfo: errInfo)))
                    }
                }
            }
    }

    /// async/await 版（抛出详细错误，调用方可使用 try/await）
    func get<T: Decodable>(path: String, parameters: [String: Any]? = nil, responseType: T.Type) async throws -> T {
        let urlString = getApiUrl(path: path)
        var urlComponents = URLComponents(string: urlString)
        if let params = parameters, !params.isEmpty {
            urlComponents?.queryItems = params.map { k, v in
                URLQueryItem(name: k, value: "\(v)")
            }
        }

        guard let url = urlComponents?.url else {
            throw NSError(domain: "TikhubHttpService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.httpMethod = "GET"
        for header in headers {
            req.setValue(header.value, forHTTPHeaderField: header.name)
        }

        // 使用 Alamofire 的 async 支持（AF.request...serializingData().response）
        let dataResponse = await AF.request(req).serializingData().response

        if let afError = dataResponse.error {
            let code = dataResponse.response?.statusCode ?? -1
            let bodyText = dataResponse.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
            throw NSError(domain: "TikhubHttpService", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Network error: \(afError.localizedDescription)",
                "statusCode": code,
                "body": bodyText
            ])
        }

        guard let data = dataResponse.data else {
            throw NSError(domain: "TikhubHttpService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data returned"])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let obj = try decoder.decode(T.self, from: data)
            return obj
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw NSError(domain: "TikhubHttpService", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "JSON decode error: \(error.localizedDescription)",
                "rawResponse": raw
            ])
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
