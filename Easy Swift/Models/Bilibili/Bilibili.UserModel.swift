//
//  UserModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/17.
//

import Foundation

struct BiliUserInfoResult: Codable {
    let code: Int
    let ttl: Int
    let message: String
    let data: BiliUserInfoData
}

struct BiliUserInfoData: Codable {
    let isLogin: Bool
    let wbi_img: BiliUserInfoWbi
    let face: String?
    let mid: Int?
    let uname: String?
    let money: Double? // 拥有硬币数
    let wallet: BiliUserInfoBcoin? // B币信息
    let vipStatus: Int?
    let vipDueDate: Int?
    // let mid: Int?
    func getBcoin() -> Double {
        return self.wallet?.bcoin_balance ?? 0
    }

    func isVip() -> Bool {
        if self.vipStatus == nil {
            return false
        } else {
            return self.vipStatus == 1
        }
    }
}

struct BiliUserInfoWbi: Codable {
    let img_url: String
    let sub_url: String
}

struct BiliUserInfoBcoin: Codable {
    let bcoin_balance: Double // 拥有B币数
    let coupon_balance: Double // 每月奖励B币数
}
