//
//  TikhubApiModel.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/19.
//

import Foundation

public struct TApiTiktokVideoInfoResult: Codable {
    public let code: Int
    public let request_id: String?
    public let message: String?
    public let message_zh: String?
    public let support: String?
    public let time: String?
    public let time_stamp: Int64? // 时间戳
    public let time_zone: String?
    public let docs: String?
    public let cache_message: String?
    public let cache_message_zh: String?
    public let cache_url: String?
    public let router: String?
    public let params: [String: String]?
    public let data: TApiTiktokVideoInfoData?

    public init(code: Int,
                request_id: String?,
                message: String?,
                message_zh: String?,
                support: String?,
                time: String?,
                time_stamp: Int64?,
                time_zone: String?,
                docs: String?,
                cache_message: String?,
                cache_message_zh: String?,
                cache_url: String?,
                router: String?,
                params: [String: String]?,
                data: TApiTiktokVideoInfoData?)
    {
        self.code = code
        self.request_id = request_id
        self.message = message
        self.message_zh = message_zh
        self.support = support
        self.time = time
        self.time_stamp = time_stamp
        self.time_zone = time_zone
        self.docs = docs
        self.cache_message = cache_message
        self.cache_message_zh = cache_message_zh
        self.cache_url = cache_url
        self.router = router
        self.params = params
        self.data = data
    }
}

public struct TApiTiktokVideoInfoData: Codable {
    public let aweme_status: [TApiAwemeStatus]?
    public let extra: TApiExtraInfo?
    public let log_pb: TApiLogPB?
    public let status_code: Int?
    public let status_msg: String?
    public let aweme_detail: TApiAwemeDetail?

    public init(aweme_status: [TApiAwemeStatus]?,
                extra: TApiExtraInfo?,
                log_pb: TApiLogPB?,
                status_code: Int?,
                status_msg: String?,
                aweme_detail: TApiAwemeDetail?)
    {
        self.aweme_status = aweme_status
        self.extra = extra
        self.log_pb = log_pb
        self.status_code = status_code
        self.status_msg = status_msg
        self.aweme_detail = aweme_detail
    }
}

public struct TApiAwemeStatus: Codable {
    public let item_id: String?
    public let status: Int?
    public let status_text: String?

    public init(item_id: String?, status: Int?, status_text: String?) {
        self.item_id = item_id
        self.status = status
        self.status_text = status_text
    }
}

public struct TApiExtraInfo: Codable {
    public let fatal_item_ids: [String]?
    public let logid: String?
    public let now: Int64?

    public init(fatal_item_ids: [String]?, logid: String?, now: Int64?) {
        self.fatal_item_ids = fatal_item_ids
        self.logid = logid
        self.now = now
    }
}

public struct TApiLogPB: Codable {
    public let impr_id: String?

    public init(impr_id: String?) {
        self.impr_id = impr_id
    }
}

public struct TApiAwemeDetail: Codable {
    // 基本标识
    public let aweme_id: String?
    public let id: Int64?
    public let id_str: String?

    // 内容描述
    public let desc: String?
    public let content_desc: String?
    public let text_extra: [AnyCodable]?

    // 创建 / 时间
    public let create_time: Int64?
    public let create_time_str: String? // 有些接口会带字符串时间

    // 作者
    public let author: TApiAuthor?
    public let owner_id: String?
    public let owner_nickname: String?
    public let owner_handle: String?

    // 视频与媒体
    public let video: TApiVideo?
    public let play_url: TApiPlayAddr? // 有些样例直接在 aweme_detail.play_url 出现
    public let play_addr: TApiPlayAddr?
    public let play_addr_h264: TApiPlayAddr?
    public let play_addr_bytevc1: TApiPlayAddr?
    public let download_no_watermark_addr: TApiPlayAddr?

    // 封面/缩略图集合
    public let cover: TApiImageSet?
    public let cover_thumb: TApiImageSet?
    public let cover_medium: TApiImageSet?
    public let cover_large: TApiImageSet?
    public let origin_cover: TApiImageSet?
    public let dynamic_cover: TApiImageSet?

    // 音乐 / sound
    public let music: TApiMusic?
    public let added_sound_music_info: TApiMusic?

    // 统计
    public let statistics: TApiStatistics?

    // 分享信息
    public let share_info: TApiShareInfo?
    public let share_url: String?

    // 属性标志
    public let has_human_voice: Bool?
    public let has_commerce_right: Bool?
    public let is_original: Bool?
    public let prevent_download: Bool?
    public let has_watermark: Bool?

    // 其他杂项（保留 raw JSON 的扩展点）
    public let extra: String?
    public let meta: String?
    public let music_begin_time_in_ms: Int?
    public let music_end_time_in_ms: Int?

    public init(aweme_id: String?,
                id: Int64?,
                id_str: String?,
                desc: String?,
                content_desc: String?,
                text_extra: [String: AnyCodable]?,
                create_time: Int64?,
                create_time_str: String?,
                author: TApiAuthor?,
                owner_id: String?,
                owner_nickname: String?,
                owner_handle: String?,
                video: TApiVideo?,
                play_url: TApiPlayAddr?,
                play_addr: TApiPlayAddr?,
                play_addr_h264: TApiPlayAddr?,
                play_addr_bytevc1: TApiPlayAddr?,
                download_no_watermark_addr: TApiPlayAddr?,
                cover: TApiImageSet?,
                cover_thumb: TApiImageSet?,
                cover_medium: TApiImageSet?,
                cover_large: TApiImageSet?,
                origin_cover: TApiImageSet?,
                dynamic_cover: TApiImageSet?,
                music: TApiMusic?,
                added_sound_music_info: TApiMusic?,
                statistics: TApiStatistics?,
                share_info: TApiShareInfo?,
                share_url: String?,
                has_human_voice: Bool?,
                has_commerce_right: Bool?,
                is_original: Bool?,
                prevent_download: Bool?,
                has_watermark: Bool?,
                extra: String?,
                meta: String?,
                music_begin_time_in_ms: Int?,
                music_end_time_in_ms: Int?)
    {
        self.aweme_id = aweme_id
        self.id = id
        self.id_str = id_str
        self.desc = desc
        self.content_desc = content_desc
        self.text_extra = text_extra
        self.create_time = create_time
        self.create_time_str = create_time_str
        self.author = author
        self.owner_id = owner_id
        self.owner_nickname = owner_nickname
        self.owner_handle = owner_handle
        self.video = video
        self.play_url = play_url
        self.play_addr = play_addr
        self.play_addr_h264 = play_addr_h264
        self.play_addr_bytevc1 = play_addr_bytevc1
        self.download_no_watermark_addr = download_no_watermark_addr
        self.cover = cover
        self.cover_thumb = cover_thumb
        self.cover_medium = cover_medium
        self.cover_large = cover_large
        self.origin_cover = origin_cover
        self.dynamic_cover = dynamic_cover
        self.music = music
        self.added_sound_music_info = added_sound_music_info
        self.statistics = statistics
        self.share_info = share_info
        self.share_url = share_url
        self.has_human_voice = has_human_voice
        self.has_commerce_right = has_commerce_right
        self.is_original = is_original
        self.prevent_download = prevent_download
        self.has_watermark = has_watermark
        self.extra = extra
        self.meta = meta
        self.music_begin_time_in_ms = music_begin_time_in_ms
        self.music_end_time_in_ms = music_end_time_in_ms
    }

    // CodingKeys: 如果服务端字段名有差异可以在这里映射
    private enum CodingKeys: String, CodingKey {
        case aweme_id, id, id_str, desc, content_desc, text_extra, create_time
        case create_time_str
        case author
        case owner_id, owner_nickname, owner_handle
        case video, play_url, play_addr, play_addr_h264, play_addr_bytevc1, download_no_watermark_addr
        case cover, cover_thumb, cover_medium, cover_large, origin_cover, dynamic_cover
        case music, added_sound_music_info, statistics, share_info, share_url
        case has_human_voice, has_commerce_right, is_original, prevent_download, has_watermark
        case extra, meta, music_begin_time_in_ms, music_end_time_in_ms
    }
}

// MARK: - Author

public struct TApiAuthor: Codable {
    public let uid: String?
    public let unique_id: String?
    public let nickname: String?
    public let avatar_thumb: TApiImageSet?
    public let avatar_medium: TApiImageSet?
    public let avatar_larger: TApiImageSet?
    public let signature: String?
    public let sec_uid: String?
    public let region: String?
    public let follower_count: Int?
    public let following_count: Int?
    public let aweme_count: Int?

    public init(uid: String?,
                unique_id: String?,
                nickname: String?,
                avatar_thumb: TApiImageSet?,
                avatar_medium: TApiImageSet?,
                avatar_larger: TApiImageSet?,
                signature: String?,
                sec_uid: String?,
                region: String?,
                follower_count: Int?,
                following_count: Int?,
                aweme_count: Int?)
    {
        self.uid = uid
        self.unique_id = unique_id
        self.nickname = nickname
        self.avatar_thumb = avatar_thumb
        self.avatar_medium = avatar_medium
        self.avatar_larger = avatar_larger
        self.signature = signature
        self.sec_uid = sec_uid
        self.region = region
        self.follower_count = follower_count
        self.following_count = following_count
        self.aweme_count = aweme_count
    }
}

// MARK: - Statistics

public struct TApiStatistics: Codable {
    public let aweme_id: String?
    public let play_count: Int?
    public let digg_count: Int?
    public let comment_count: Int?
    public let share_count: Int?
    public let download_count: Int?
    public let collect_count: Int?
    public let forward_count: Int?
    public let repost_count: Int?
    public let whatsapp_share_count: Int?
    public let lose_count: Int?
    public let lose_comment_count: Int?

    public init(aweme_id: String?,
                play_count: Int?,
                digg_count: Int?,
                comment_count: Int?,
                share_count: Int?,
                download_count: Int?,
                collect_count: Int?,
                forward_count: Int?,
                repost_count: Int?,
                whatsapp_share_count: Int?,
                lose_count: Int?,
                lose_comment_count: Int?)
    {
        self.aweme_id = aweme_id
        self.play_count = play_count
        self.digg_count = digg_count
        self.comment_count = comment_count
        self.share_count = share_count
        self.download_count = download_count
        self.collect_count = collect_count
        self.forward_count = forward_count
        self.repost_count = repost_count
        self.whatsapp_share_count = whatsapp_share_count
        self.lose_count = lose_count
        self.lose_comment_count = lose_comment_count
    }
}

// MARK: - Video / PlayAddr / DownloadAddr

public struct TApiVideo: Codable {
    public let duration: Int?
    public let width: Int?
    public let height: Int?
    public let ratio: String?
    public let play_addr: TApiPlayAddr?
    public let play_addr_h264: TApiPlayAddr?
    public let play_addr_bytevc1: TApiPlayAddr?
    public let download_no_watermark_addr: TApiPlayAddr?
    public let dynamic_cover: TApiImageSet?
    public let cover: TApiImageSet?

    public init(duration: Int?, width: Int?, height: Int?, ratio: String?, play_addr: TApiPlayAddr?, play_addr_h264: TApiPlayAddr?, play_addr_bytevc1: TApiPlayAddr?, download_no_watermark_addr: TApiPlayAddr?, dynamic_cover: TApiImageSet?, cover: TApiImageSet?) {
        self.duration = duration
        self.width = width
        self.height = height
        self.ratio = ratio
        self.play_addr = play_addr
        self.play_addr_h264 = play_addr_h264
        self.play_addr_bytevc1 = play_addr_bytevc1
        self.download_no_watermark_addr = download_no_watermark_addr
        self.dynamic_cover = dynamic_cover
        self.cover = cover
    }
}

public struct TApiPlayAddr: Codable {
    public let data_size: Int?
    public let uri: String?
    public let url_list: [String]?
    public let width: Int?
    public let height: Int?
    public let mime_type: String?

    public init(data_size: Int?, uri: String?, url_list: [String]?, width: Int?, height: Int?, mime_type: String?) {
        self.data_size = data_size
        self.uri = uri
        self.url_list = url_list
        self.width = width
        self.height = height
        self.mime_type = mime_type
    }
}

// MARK: - Image set (cover / avatar)

public struct TApiImageSet: Codable {
    public let data_size: Int?
    public let height: Int?
    public let uri: String?
    public let url_list: [String]?
    public let url_prefix: String?
    public let width: Int?

    public init(data_size: Int?, height: Int?, uri: String?, url_list: [String]?, url_prefix: String?, width: Int?) {
        self.data_size = data_size
        self.height = height
        self.uri = uri
        self.url_list = url_list
        self.url_prefix = url_prefix
        self.width = width
    }
}

// MARK: - Music

public struct TApiMusic: Codable {
    public let album: String?
    public let author: String?
    public let avatar_medium: TApiImageSet?
    public let audition_duration: Int?
    public let music_vid: String?
    public let title: String?

    public init(album: String?, author: String?, avatar_medium: TApiImageSet?, audition_duration: Int?, music_vid: String?, title: String?) {
        self.album = album
        self.author = author
        self.avatar_medium = avatar_medium
        self.audition_duration = audition_duration
        self.music_vid = music_vid
        self.title = title
    }
}

// MARK: - Share info

public struct TApiShareInfo: Codable {
    public let share_desc: String?
    public let share_title: String?
    public let share_url: String?
    public let share_qrcode_url: TApiImageSet?

    public init(share_desc: String?, share_title: String?, share_url: String?, share_qrcode_url: TApiImageSet?) {
        self.share_desc = share_desc
        self.share_title = share_title
        self.share_url = share_url
        self.share_qrcode_url = share_qrcode_url
    }
}

// MARK: - AnyCodable helper (用于不定结构的 text_extra 等)

/// 简单 AnyCodable，用于把未知结构解析为 Codable-friendly 值
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            self.value = b
        } else if let i = try? container.decode(Int.self) {
            self.value = i
        } else if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self) {
            self.value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            var out: [String: Any] = [:]
            for (k, v) in dict {
                out[k] = v.value
            }
            self.value = out
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            let enc = arr.map { AnyCodable($0) }
            try container.encode(enc)
        case let dict as [String: Any]:
            let enc = Dictionary(uniqueKeysWithValues: dict.map { ($0, AnyCodable($1)) })
            try container.encode(enc)
        default:
            let str = String(describing: value)
            try container.encode(str)
        }
    }
}

// MARK: - Convenience: 摘要结构（供业务层直接使用）

public struct TApiTiktokVideoSummary {
    public let awemeID: String
    public let title: String
    public let authorName: String?
    public let authorID: String?
    public let bestPlayURL: String?
    public let playCount: Int?

    public init(awemeDetail: TApiAwemeDetail) {
        self.awemeID = awemeDetail.aweme_id ?? (awemeDetail.id_str ?? "")
        self.title = awemeDetail.desc ?? ""
        self.authorName = awemeDetail.author?.nickname
        self.authorID = awemeDetail.author?.uid
        self.playCount = awemeDetail.statistics?.play_count

        func firstURL(_ addr: TApiPlayAddr?) -> String? { addr?.url_list?.first }

        self.bestPlayURL =
            firstURL(awemeDetail.download_no_watermark_addr) ??
            firstURL(awemeDetail.play_addr_h264) ??
            firstURL(awemeDetail.play_addr_bytevc1) ??
            firstURL(awemeDetail.play_addr) ??
            firstURL(awemeDetail.play_url)
    }
}
