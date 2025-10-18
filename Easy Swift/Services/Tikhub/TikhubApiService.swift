//
//  TikhubTikhubService.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/16.
//

import Foundation

class TikhubApiService {
    private let http = TikhubHttp()
    init() {}
    func getTiktokVideoInfoByShareUrl(shareUrl: String) async throws -> TikhubTiktokVideoInfoResponseModel {
        let path = "/api/v1/tiktok/app/v3/fetch_one_video_by_share_url"
        let parameters = [
            "share_url": shareUrl
    ]
        let response: TikhubTiktokVideoInfoResponseModel = try await http.get(path: path, parameters: parameters)
        return response
    
        
}
