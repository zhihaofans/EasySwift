//
//  LinkHistoryModelTests.swift
//  Easy SwiftTests
//

import Foundation
import Testing

@testable import Easy_Swift

struct LinkHistoryModelTests {
    private func item(images: Int, videos: Int = 0, motions: Int = 0, platform: String = "小红书") -> LinkHistoryItem {
        LinkHistoryItem(sourceURL: "https://xhslink.cn/o/abc",
                        finalURL: "https://www.xiaohongshu.com/discovery/item/1",
                        platform: platform,
                        title: "标题",
                        coverURL: nil,
                        imageCount: images,
                        videoCount: videos,
                        motionCount: motions,
                        create_time_ms: 1_700_000_000_000)
    }

    @Test func summaryIncludesPlatformAndCounts() {
        #expect(item(images: 7, motions: 3).summary == "小红书 · 7 图（3 动图）")
        #expect(item(images: 4).summary == "小红书 · 4 图")
        #expect(item(images: 0, videos: 2).summary == "小红书 · 2 视频")
        #expect(item(images: 6, videos: 1, platform: "抖音").summary == "抖音 · 6 图 + 1 视频")
    }

    @Test func summaryHandlesUnknownPlatform() {
        #expect(item(images: 1, platform: "").summary == "1 图")
    }

    /// 毫秒时间戳换算回日期（秒级会差 1000 倍，这条就是防它回来）
    @Test func dateComesFromMilliseconds() {
        let expected=Date(timeIntervalSince1970: 1_700_000_000)
        #expect(abs(item(images: 1).date.timeIntervalSince(expected)) < 1)
    }
}
