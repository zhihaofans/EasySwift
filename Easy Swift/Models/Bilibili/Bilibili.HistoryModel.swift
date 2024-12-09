//
//  HistoryModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/18.
//

import Foundation

// History
struct BiliHistoryResult: Codable {
    let code: Int
    let message: String
    let data: BiliHistoryData
}

struct BiliHistoryData: Codable {
    let list: [BiliHistoryItem]
}

struct BiliHistoryItem: Codable {
    let title: String
    let author_name: String
    let author_face: String
    let author_mid: Int
    let view_at: Int
    let cover: String?
    let covers: [String]?
    let history: BiliHistoryItemInfo
    let uri: String
    func getCover() -> String {
        let cover = self.covers?[0] ?? self.cover ?? "https://http.cat/images/404.jpg"
        return cover.replacingOccurrences(of: "http://", with: "https://")
    }
}

struct BiliHistoryItemInfo: Codable {
    let business: String
    private let dt: Int
    let oid: Int? // 稿件视频&剧集avid、直播、文章、文集
    let epid: Int?
    let bvid: String?
    func getId() -> String {
        switch self.business {
            case "archive":
                return self.bvid!
            case "pgc":
                return self.epid!.toString
            case "live", "article", "article-list":
                return self.oid!.toString
            default:
                return ""
        }
    }

    func getType() -> String {
        return self.business
    }
}

// Later to watch
struct BiliLater2WatchResult: Codable {
    let code: Int
    let message: String
    let data: BiliLater2WatchData
}

struct BiliLater2WatchData: Codable {
    let list: [BiliLater2WatchItem]
    let count: Int
}

struct BiliLater2WatchItem: Codable {
    let title: String
    let desc: String
    let uri: String
    let add_at: Int
    let ctime: Int
    let pic: String
    let first_frame: String?
    let pub_location: String?
    let cid: Int // 稿件视频&剧集avid、直播、文章、文集?
    let aid: Int
    let bvid: String
    let videos: Int // 多少分P
    let owner: BiliHistoryItemOwner
}

struct BiliHistoryItemOwner: Codable {
    let mid: Int
    let name: String
    let face: String
}

// Add Later to watch
struct BiliAddLater2WatchResult: Codable {
    let code: Int
    let message: String
}
