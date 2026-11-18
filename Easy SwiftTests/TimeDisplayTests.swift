//
//  TimeDisplayTests.swift
//  Easy SwiftTests
//
//  列表时间显示改成了相对时间。这条用例钉住两件事：
//  1. 用的是用户 locale（不是硬编码中文）；
//  2. 未来时间不会被说成「刚刚」（这是 RelativeTimeFormatter 相对手写实现的关键差别）。
//

import Foundation
import Testing
import SwiftUtils

struct TimeDisplayTests {
    private let now=Date(timeIntervalSince1970: 1_700_000_000)
    private let zh=Locale(identifier: "zh_CN")
    private let shanghai=TimeZone(identifier: "Asia/Shanghai")!

    @Test func pastMinutesReadAsRelative() {
        let threeMinutesAgo=now.addingTimeInterval(-180)
        let text=RelativeTimeFormatter.string(from: threeMinutesAgo, now: now, locale: zh, timeZone: shanghai)
        #expect(text.contains("3"))
        #expect(text.contains("分钟"))
    }

    @Test func yesterdayUsesNamedStyle() {
        let yesterday=now.addingTimeInterval(-86400)
        let text=RelativeTimeFormatter.string(from: yesterday, now: now, locale: zh, timeZone: shanghai)
        #expect(text.contains("昨天"))
    }

    /// 未来时间不能被说成「刚刚」（手写实现最容易踩的坑）
    @Test func futureIsNotJustNow() {
        let tomorrow=now.addingTimeInterval(86400)
        let text=RelativeTimeFormatter.string(from: tomorrow, now: now, locale: zh, timeZone: shanghai)
        #expect(!text.contains("刚刚"))
        #expect(text.contains("明天") || text.contains("1") || text.contains("后"))
    }

    /// 英文 locale 下不出中文
    @Test func respectsLocale() {
        let threeMinutesAgo=now.addingTimeInterval(-180)
        let text=RelativeTimeFormatter.string(from: threeMinutesAgo,
                                              now: now,
                                              locale: Locale(identifier: "en_US"),
                                              timeZone: TimeZone(identifier: "America/New_York")!)
        #expect(text.lowercased().contains("minute"))
        #expect(!text.contains("分钟"))
    }
}
