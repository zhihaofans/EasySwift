//
//  LinkHistoryModel.swift
//  Easy Swift
//
//  解析历史：一条解析成功的链接留个痕，方便回看与重新解析。
//
//  注意：历史里的**直链会过期**（小红书/抖音的图片视频地址都带时效签名），
//  所以点开历史条目是"重新解析"，不能把旧的 images/videos 当结果直接用。
//

import Foundation
import SwiftData

@Model
final class LinkHistoryItem {
    var id: UUID
    /// 用户粘贴进来的原始链接（可能是短链，原样留着方便再给解析器）
    var sourceURL: String
    /// 展开后的最终地址；去重按它算（短链不同、指向同一篇时只留一条）
    var finalURL: String
    /// 平台名（"小红书" / "抖音"；解不出来就是空串）
    var platform: String
    var title: String
    /// 封面：优先视频封面，其次第一张图
    var coverURL: String?
    var imageCount: Int
    var videoCount: Int
    var motionCount: Int
    /// Unix **毫秒**：排序要用毫秒，秒级会把同一秒内的多条排成随机顺序
    /// （实测：205 条同秒写入，裁剪后留下的不是最新的那条）
    var create_time_ms: Int

    init(id: UUID = UUID(),
         sourceURL: String,
         finalURL: String,
         platform: String,
         title: String,
         coverURL: String?,
         imageCount: Int,
         videoCount: Int,
         motionCount: Int,
         create_time_ms: Int)
    {
        self.id=id
        self.sourceURL=sourceURL
        self.finalURL=finalURL
        self.platform=platform
        self.title=title
        self.coverURL=coverURL
        self.imageCount=imageCount
        self.videoCount=videoCount
        self.motionCount=motionCount
        self.create_time_ms=create_time_ms
    }

    var date: Date { Date(timeIntervalSince1970: TimeInterval(create_time_ms) / 1000) }

    /// 列表里显示的一句话摘要：「小红书 · 8 图（3 动图）」
    var summary: String {
        var parts: [String]=[]
        if !platform.isEmpty { parts.append(platform) }
        var media: [String]=[]
        if imageCount > 0 {
            media.append(motionCount > 0 ? "\(imageCount) 图（\(motionCount) 动图）" : "\(imageCount) 图")
        }
        if videoCount > 0 { media.append("\(videoCount) 视频") }
        if !media.isEmpty { parts.append(media.joined(separator: " + ")) }
        return parts.joined(separator: " · ")
    }
}
