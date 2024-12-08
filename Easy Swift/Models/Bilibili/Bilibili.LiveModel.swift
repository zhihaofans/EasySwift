//
//  LiveModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/23.
//

import Foundation

// 直播获取个人信息
struct BiliLiveUserInfoResult: Codable {
    let code: Int
    let message: String
    let data: BiliLiveUserInfoData
}

struct BiliLiveUserInfoData: Codable {
    // let list: [LaterWatchList]
    let user_level: Int
    let user_intimacy: Int
    let vip: Int
    let uid: Int
    let billCoin: Double
    let svip: Int
    let user_next_level: Int
    let user_next_intimacy: Int
    let is_level_top: Int
    let user_charged: Int
    let identification: Int
    let uname: String
    let user_level_rank: String
    let gold: Int
    let achieve: Int
    let face: String
    let silver: Int
    let wealth_info: BiliLiveUserInfoWealthData
}

struct BiliLiveUserInfoWealthData: Codable {
    let status: Int
    let uid: Int
    let level: Int
    let upgrade_need_score: Int
    let level_total_score: Int
    let dm_icon_key: String
    let cur_score: Int
}

// 直播签到

struct BiliLiveCheckinResult: Codable {
    let code: Int
    let message: String
}
