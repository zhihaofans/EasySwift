//
//  TikhubTikhubService.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/16.
//

import Foundation

enum TikhubApiError: Error, LocalizedError {
    case networkError(String)
    case invalidResponse(String)
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let s): return "Network error: \(s)"
        case .invalidResponse(let s): return "Invalid response: \(s)"
        case .apiError(let code, let message): return "API error (\(code)): \(message)"
        }
    }
}

class TikhubApiService {
    private let http = TikhubHttpService()
    init() {}
    func getTiktokVideoInfoByShareUrl(shareUrl: String) async throws -> TApiTiktokVideoInfoResult {
        let path = "/api/v1/tiktok/app/v3/fetch_one_video_by_share_url"
        let parameters: [String: Any] = [
            "share_url": shareUrl
        ]

        // 发起请求并解码为模型（TikhubHttpService.get 要求传入 responseType 参数）
        let response: TApiTiktokVideoInfoResult
        do {
            // 注意：这里把 responseType 明确传入
            response = try await http.get(path: path, parameters: parameters, responseType: TApiTiktokVideoInfoResult.self)
        } catch {
            // 将底层错误包装成更友好的 API 错误
            throw TikhubApiError.networkError(error.localizedDescription)
        }

        // 检查顶层 API code（假设你的模型里有 code: Int, message: String? 等字段）
        if response.code != 200 {
            // 尽量以英文 message 为主，若为空则回退到中文或 Unknown
            let msg = (response.message?.isEmpty == false) ? response.message! : (response.message_zh ?? "Unknown")
            throw TikhubApiError.apiError(code: response.code, message: msg)
        }

        // 业务校验：确保 data 与 aweme_detail 存在
        if response.data?.aweme_detail == nil {
            throw TikhubApiError.invalidResponse("`data.aweme_detail` is missing in API response")
        }

        // 一切正常，直接返回模型
        return response
    }
}
