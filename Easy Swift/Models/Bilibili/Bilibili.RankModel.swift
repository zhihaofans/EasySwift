//
//  RankModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/10/28.
//

import Foundation

// Rank
struct BiliRankResult: Codable {
    let code: Int
    let message: String
    let data: BiliRankData?
}

struct BiliRankData: Codable {
    let note: String
    let list: [BiliVideoInfoData]
}

struct BiliRankInfoData: Codable {
    let bvid: String
    let aid: Int
    let videos: Int // 稿件分P总数
    let pic: String
    let cover43: String
    let title: String
    let pubdate: Int // 稿件发布时间
//    let pub_location: String // 稿件发布定位
    let ctime: Int // 用户投稿时间
    let desc: String
    let duration: Int // 稿件总时长(所有分P)
    let owner: BiliRankInfoOwner
    let dynamic: String // 视频同步发布的的动态的文字内容
    let short_link_v2: String
    let tname: String // 分区类型
}

struct BiliRankInfoOwner: Codable {
    let mid: Int
    let name: String
    let face: String
}
