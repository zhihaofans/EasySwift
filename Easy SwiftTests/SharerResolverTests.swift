//
//  SharerResolverTests.swift
//  Easy SwiftTests
//
//  分享者解析的纯函数：这些之前只能用仓库外 harness 跑，现在是正式用例。
//

import Foundation
import Testing

@testable import Easy_Swift

struct SharerResolverTests {
    /// 真实分享令牌 → 24 位 hex 账号 ID（2026-11-05 实测值，别改成"看起来像"的假数据）
    @Test func rednoteAccountIDFromRealShareRedID() {
        let id=SharerResolver.rednoteAccountID(fromShareRedID: "N0s2QklJRko2NzUyOTgwNjY0OTc8Oz1B")
        #expect(id == "5e4bfdba0000000001008678")
    }

    @Test func rednoteAccountIDRejectsGarbage() {
        #expect(SharerResolver.rednoteAccountID(fromShareRedID: "short") == nil)
        #expect(SharerResolver.rednoteAccountID(fromShareRedID: "") == nil)
        #expect(SharerResolver.rednoteAccountID(fromShareRedID: "!!!!") == nil)
    }

    /// 三种历史结构都取得到昵称（接口改过形态，按数据特征找而不是钉死键名）
    @Test func rednoteNicknameFromVariousStates() {
        let pageData: [String: Any]=["user": ["userPageData": ["userInfo": ["nickname": "甲"]]]]
        #expect(SharerResolver.rednoteNickname(fromState: pageData) == "甲")

        let userInfo: [String: Any]=["user": ["userInfo": ["nickname": "乙"]]]
        #expect(SharerResolver.rednoteNickname(fromState: userInfo) == "乙")

        let profile: [String: Any]=["profile": ["userInfo": ["nickname": "丙"]]]
        #expect(SharerResolver.rednoteNickname(fromState: profile) == "丙")
    }

    @Test func rednoteNicknameRejectsBlankAndNull() {
        #expect(SharerResolver.rednoteNickname(fromState: [:]) == nil)
        #expect(SharerResolver.rednoteNickname(fromState: ["user": ["userInfo": ["nickname": "   "]]]) == nil)
        #expect(SharerResolver.rednoteNickname(fromState: ["user": ["userInfo": ["nickname": "null"]]]) == nil)
        #expect(SharerResolver.rednoteNickname(fromState: ["user": ["userInfo": ["nickname": 42]]]) == nil)
    }

    /// 抖音的短 ID 编码是 base23，反解再编码必须回到原值
    @Test func douyinUIDRoundTrip() {
        for uid in ["1234567890123", "9876543210987", "1000000000001"] {
            guard let code=SharerResolver.douyinEncodeUID(uid) else {
                Issue.record("编码失败 uid=\(uid)")
                continue
            }
            #expect(SharerResolver.douyinDecodeUCode(code) == uid, "uid=\(uid) code=\(code)")
        }
    }

    /// 注意：`a`~`m` 是 base23 的合法字符（字母表是 0-9 + a-m），
    /// 所以"abc"能正常解码 —— 只有字母表外的字符才算非法（我第一次就把这条写错了）
    @Test func douyinDecodeBoundaries() {
        #expect(SharerResolver.douyinDecodeUCode("") == nil)
        #expect(SharerResolver.douyinDecodeUCode("z") == nil)
        #expect(SharerResolver.douyinDecodeUCode("12x") == nil)
        #expect(SharerResolver.douyinDecodeUCode("0") == "0")
        #expect(SharerResolver.douyinDecodeUCode("abc") != nil)
    }
}
