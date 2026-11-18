//
//  InboxClassifierTests.swift
//  Easy SwiftTests
//

import Foundation
import Testing

@testable import Easy_Swift

struct InboxClassifierTests {
    @Test func classifiesPlatformLinks() {
        #expect(InboxClassifier.classify("https://xhslink.cn/o/abc").kind == .xiaohongshu)
        #expect(InboxClassifier.classify("https://www.xiaohongshu.com/discovery/item/1").kind == .xiaohongshu)
        #expect(InboxClassifier.classify("https://v.douyin.com/xyz").kind == .douyin)
        #expect(InboxClassifier.classify("https://www.douyin.com/video/1").kind == .douyin)
    }

    @Test func classifiesGenericLinkAndText() {
        #expect(InboxClassifier.classify("https://example.com/a").kind == .link)
        #expect(InboxClassifier.classify("随便一句话，没有链接").kind == .text)
        #expect(InboxClassifier.classify("   ").kind == .text)
    }

    /// 一整段分享文案里要能挑出链接（小红书/抖音分享出来的都是一大段）
    @Test func extractsLinkFromShareText() {
        let text="南京我最红🔥 复制后打开小红书 https://xhslink.cn/o/7wAkW1PBaXP 看到这篇笔记"
        let result=InboxClassifier.classify(text)
        #expect(result.kind == .xiaohongshu)
        #expect(result.link?.absoluteString == "https://xhslink.cn/o/7wAkW1PBaXP")
    }

    /// 大小写 / 带 www 都要认
    @Test func hostMatchingIsCaseInsensitive() {
        #expect(InboxClassifier.classify("https://WWW.XIAOHONGSHU.COM/discovery/item/1").kind == .xiaohongshu)
        #expect(InboxClassifier.classify("https://V.DOUYIN.COM/abc").kind == .douyin)
    }
}
