//
//  ImageCacheKeyTests.swift
//  Easy SwiftTests
//
//  缓存键决定了"同一张图会不会被重复下载"。抖音的图会换子域名 + 换签名，
//  这条用例就是防止有人把键改回完整 URL（改回去的话缓存等于失效）。
//

import Foundation
import Testing

@testable import Easy_Swift

struct ImageCacheKeyTests {
    private func canonical(_ string: String) -> String {
        RemoteImageCache.canonical(url: URL(string: string)!)
    }

    @Test func douyinSignatureChangesDoNotChangeKey() {
        let a="https://p3-pc-sign.douyinpic.com/tos-cn-i-0813/oQabc~tplv-dy-aweme-images:q75.webp?x-expires=1&x-signature=AAA"
        let b="https://p3-pc-sign.douyinpic.com/tos-cn-i-0813/oQabc~tplv-dy-aweme-images:q75.webp?x-expires=2&x-signature=BBB"
        #expect(canonical(a) == canonical(b))
    }

    /// 实测：同一张图会在 p3-pc-sign / p9-sign / p11-sign 之间换子域名
    @Test func douyinSubdomainRotationDoesNotChangeKey() {
        let a="https://p3-pc-sign.douyinpic.com/tos-cn-i-0813/oQabc~tplv-dy-aweme-images:q75.webp"
        let b="https://p11-sign.douyinpic.com/tos-cn-i-0813/oQabc~tplv-dy-aweme-images:q75.webp"
        #expect(canonical(a) == canonical(b))
        #expect(canonical(a) == "/tos-cn-i-0813/oQabc~tplv-dy-aweme-images:q75.webp")
    }

    @Test func differentImagesKeepDifferentKeys() {
        let a="https://p3-sign.douyinpic.com/tos-cn-i-0813/AAA~tplv-dy.webp"
        let b="https://p3-sign.douyinpic.com/tos-cn-i-0813/BBB~tplv-dy.webp"
        #expect(canonical(a) != canonical(b))
    }

    @Test func xiaohongshuCDNIsNormalized() {
        let a="https://sns-img-bd.xhscdn.com/abc123?imageView2/2/w/1080&x-expires=1"
        let b="https://sns-img-qc.xhscdn.com/abc123?imageView2/2/w/1080&x-expires=2"
        #expect(canonical(a) == canonical(b))
        #expect(canonical(a) == "/abc123")
    }

    /// 普通站点只剥易变参数，其它参数可能真在区分内容
    @Test func genericHostDropsOnlyVolatileParams() {
        let a="https://example.com/pic.jpg?token=abc&v=1"
        let b="https://example.com/pic.jpg?token=xyz&v=1"
        let c="https://example.com/pic.jpg?token=abc&v=2"
        #expect(canonical(a) == canonical(b))
        #expect(canonical(a) != canonical(c))
    }

    @Test func sizeIsPartOfTheKey() {
        let url=URL(string: "https://p3-sign.douyinpic.com/tos-cn-i-0813/AAA~tplv-dy.webp")!
        #expect(RemoteImageCache.key(url: url, maxPixelSize: 200) != RemoteImageCache.key(url: url, maxPixelSize: 1200))
    }

    @Test func transientStatusCodes() {
        #expect(RemoteImageCache.isTransient(status: 503))
        #expect(RemoteImageCache.isTransient(status: 500))
        #expect(RemoteImageCache.isTransient(status: 429))
        #expect(RemoteImageCache.isTransient(status: 408))
        #expect(!RemoteImageCache.isTransient(status: 403))
        #expect(!RemoteImageCache.isTransient(status: 404))
        #expect(!RemoteImageCache.isTransient(status: 200))
    }
}
