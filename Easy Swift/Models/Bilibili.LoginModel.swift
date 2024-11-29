//
//  Bilibili.LoginModel.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/30.
//

import Foundation

struct BilibiliLoginQrcodeResult: Codable {
    let code: Int
    let message: String
    let data: BilibiliLoginQrcodeData
}

struct BilibiliLoginQrcodeData: Codable {
    let url: String
    let qrcode_key: String
}

struct BilibiliLoginQrcodeCheckResult: Codable {
    let code: Int
    let message: String
    let data: BilibiliLoginQrcodeCheckData
}

struct BilibiliLoginQrcodeCheckData: Codable {
    let url: String
    let refresh_token: String
    let timestamp: Int
    let code: Int
    let message: String
}
