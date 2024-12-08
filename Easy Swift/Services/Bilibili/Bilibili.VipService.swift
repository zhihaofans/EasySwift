//
//  VipService.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/31.
//

import Alamofire
import Foundation
import SwiftUtils

class BiliVipService {
    private let http = HttpUtil()
    private let headers: HTTPHeaders = [
        "Cookie": BiliLoginService().getCookiesString(),
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "https://big.bilibili.com/mobile/bigPoint/task",
    ]
    init() {
        http.setHeader(headers)
    }

    func bipPointCheckin(callback: @escaping (BiliVipCheckinResult)->Void, fail: @escaping (String)->Void) {
        let url = "https://api.bilibili.com/pgc/activity/score/task/sign"
        http.post(url) { result in
            if result.isEmpty {
                fail("result.isEmpty")
            } else {
                print(result)
                do {
                    let data = try JSONDecoder().decode(BiliVipCheckinResult.self, from: result.data(using: .utf8)!)
                    debugPrint(data.code)
                    if data.code == 0 {
                        callback(data)
                    } else {
                        fail("Code \(data.code): \(data.message)")
                    }
                } catch {
                    print(error)
                    print("bipPointCheckin.catch.error")
                    fail("bipPointCheckin:\(error)")
                }
            }
        } fail: { error in
            print(error)
            print("bipPointCheckin.http.error")
            fail("bipPointCheckin:\(error)")
        }
    }

    func experienceCheckin(callback: @escaping (BiliVipExperienceCheckinResult)->Void, fail: @escaping (String)->Void) {
        let url = "https://api.bilibili.com/x/vip/experience/add"
        let parameters = ["csrf": BiliLoginService().getbili_jct()]
        http.post(url, body: parameters) { result in
            if result.isEmpty {
                fail("result.isEmpty")
            } else {
                print(result)
                do {
                    let data = try JSONDecoder().decode(BiliVipExperienceCheckinResult.self, from: result.data(using: .utf8)!)
                    debugPrint(data.code)
                    if data.code == 0 {
                        callback(data)
                    } else {
                        fail("Code \(data.code): \(data.message)")
                    }
                } catch {
                    print(error)
                    print("bipPointCheckin.catch.error")
                    fail("bipPointCheckin:\(error)")
                }
            }
        } fail: { error in
            print(error)
            print("bipPointCheckin.http.error")
            fail("bipPointCheckin:\(error)")
        }
    }
}
