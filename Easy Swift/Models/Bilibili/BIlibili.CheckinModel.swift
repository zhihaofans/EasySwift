//
//  CheckinModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/18.
//

import Foundation

struct BiliMangaCheckinResult: Codable {
    let code: Int
    let msg: String
}

struct BiliVipCheckinResult: Codable {
    let code: Int
    let message: String
//    let data: BiliVipCheckinData?
}

// struct BiliVipCheckinData: Codable {
//    let text: String
//    let specialText: String
//    let allDays: Int
//    let hadSignDays: Int
//    let isBonusDay: Int
// }

// TODO: {"code":0,"message":"0","ttl":1,"data":{"text":"3000点用户经验,2根辣条","specialText":"再签到14天可以获得50根辣条","allDays":30,"hadSignDays":6,"isBonusDay":0}}

struct BiliVipExperienceCheckinResult: Codable {
    let code: Int
    let message: String
//    let data: VipExperienceCheckinData?
}
