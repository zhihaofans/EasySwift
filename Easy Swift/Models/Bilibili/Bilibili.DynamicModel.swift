//
//  DynamicModel.swift
//  Bili-Swift
//
//  Created by zzh on 2024/10/6.
//

import Foundation

class BiliDynamicType {
    let FORWARD = "DYNAMIC_TYPE_FORWARD" // 转发
    let VIDEO = "DYNAMIC_TYPE_AV" // 投稿视频
    let PGC = "DYNAMIC_TYPE_PGC" // 剧集（番剧、电影、纪录片）
    let WORD = "DYNAMIC_TYPE_WORD" // 纯文字动态
    let DRAW = "DYNAMIC_TYPE_DRAW" // 带图动态
    let LIVE = "DYNAMIC_TYPE_LIVE" // 直播间分享
    let ARTICLE = "DYNAMIC_TYPE_ARTICLE" // 专栏
    let LIVE_RCMD = "DYNAMIC_TYPE_LIVE_RCMD" // 直播开播
    let NONE = "DYNAMIC_TYPE_NONE" // 无效动态
}

struct BiliDynamicListResult: Codable {
    let code: Int
    let message: String
    let data: BiliDynamicListData?
}

struct BiliDynamicListData: Codable {
    let has_more: Bool
    let offset: String
    let update_baseline: String
    let update_num: Int
    let items: [BiliDynamicListItem]
}

struct BiliDynamicListItem: Codable {
    let visible: Bool
    let id_str: String
    let type: String
    let basic: BiliDynamicListItemBasic
    let modules: BiliDynamicListItemModules
    let orig: BiliDynamicListForwardItem?
    func getCover() -> String? {
        var coverUrl: String? = nil
        if self.modules.module_dynamic.major != nil {
            coverUrl = self.modules.module_dynamic.major?.getCover()
        }
        return coverUrl ?? self.modules.module_author.face
    }

//    func getTitle() -> String {
//        switch self.type {
//        case DynamicType().VIDEO:
//            return self.modules.module_dynamic.major?.archive?.title ?? "[标题神秘消失了]"
//        case DynamicType().WORD:
//            return self.modules.module_dynamic.desc?.text ?? "[文字神秘消失了]"
//        case DynamicType().DRAW:
//            return self.modules.module_dynamic.desc?.text ?? "[发了图片]"
//        case DynamicType().ARTICLE:
//            return self.modules.module_dynamic.major?.article?.title ?? "[标题神秘消失了]"
//        case DynamicType().FORWARD:
//            return "[转发]\(self.modules.module_dynamic.getTitle() ?? "[文字神秘消失了]")"
//        default:
//            return "[\(self.type)]"
//        }
//    }
    func getTitle() -> String {
        return self.modules.module_dynamic.major?.archive?.title ?? self.modules.module_dynamic.major?.article?.title ?? self.modules.module_dynamic.desc?.text ?? self.modules.module_dynamic.getTitle() ?? "[文字神秘消失了]"
    }
}

struct BiliDynamicListForwardItem: Codable {
    let visible: Bool
    let id_str: String
    let type: String
    let basic: BiliDynamicListItemBasic
    let modules: BiliDynamicListItemModules
    func getCover() -> String? {
        return self.modules.module_dynamic.major?.getCover()
    }

    func getTitle() -> String {
        return self.modules.module_dynamic.major?.archive?.title ?? self.modules.module_dynamic.major?.article?.title ?? self.modules.module_dynamic.desc?.text ?? self.modules.module_dynamic.getTitle() ?? "[文字神秘消失了]"
    }
}

struct BiliDynamicListItemBasic: Codable {
    let comment_id_str: String
    let comment_type: Int
    // let like_icon:{}
    let rid_str: String
}

struct BiliDynamicListItemModules: Codable {
    let module_author: BiliDynamicListItemModuleAuthor
    let module_dynamic: BiliDynamicListItemModuleDynamic
    //  let module_more    obj    动态右上角三点菜单
    //  let  module_stat    obj    动态统计数据
//    module_interaction    obj    热度评论
//    module_fold    obj    动态折叠信息
//    module_dispute    obj    争议小黄条
//    module_tag    obj    置顶信息
}

struct BiliDynamicListItemModuleAuthor: Codable {
    let face: String
    let jump_url: String
    let label: String // 名称前标签：合集、电视剧、番剧
    let mid: Int // UP主UID、剧集SeasonId
    let name: String // UP主名称、剧集名称、合集名称
    let pub_action: String // 更新动作描述
    let pub_time: String // 更新时间：x分钟前、x小时前、昨天
    let pub_ts: Int // 更新时间戳    UNIX 秒级时间戳
}

struct BiliDynamicListItemModuleDynamic: Codable {
//    let additional: obj? // 相关内容卡片信息
    let desc: BiliDynamicListItemModuleDynamicDesc? // 动态文字内容,其他动态时为null
    let major: BiliDynamicListItemModuleDynamicMajor? // 动态主体对象,转发动态时为null
//    let topic: Obj? // 话题信息
    func getCover() -> String? {
        if self.major != nil {
            return self.major?.getCover()
        }
        return nil
    }

    func getTitle() -> String? {
        if self.desc != nil {
            return self.desc?.text
        } else if self.major != nil {
            return self.major?.getTitle()
        } else {
            return nil
        }
    }
}

struct BiliDynamicListItemModuleDynamicDesc: Codable {
//    let rich_text_nodes: [String]
    let text: String
}

struct BiliDynamicListItemModuleDynamicMajor: Codable {
    let type: String // 动态主体类型
    let archive: BiliDynamicListItemModuleDynamicMajorArchive? // type=MAJOR_TYPE_ARCHIVE  视频
    let draw: BiliDynamicListItemModuleDynamicMajorDraw? // type=MAJOR_TYPE_DRAW
    let live_rcmd: BiliDynamicListItemModuleDynamicMajorLiveRcmd? // type=DYNAMIC_TYPE_LIVE_RCMD
    let article: BiliDynamicListItemModuleDynamicMajorArticle? // type=MAJOR_TYPE_ARTICLE
    func getCover() -> String? {
        switch self.type {
        case BiliDynamicType().VIDEO:
            return self.archive?.cover
        case BiliDynamicType().DRAW:
            return self.draw?.items[0].src
        default:
            return nil
        }
    }

    func getTitle() -> String? {
        switch self.type {
        case BiliDynamicType().VIDEO:
            return self.archive?.title
        case BiliDynamicType().ARTICLE:
            return self.archive?.title
//        case "MAJOR_TYPE_DRAW":
//            return self.draw?.id.toString
        default:
            return nil
        }
    }
}

struct BiliDynamicListItemModuleDynamicMajorArchive: Codable {
    let aid: String // 视频AV号
//    badge    obj    角标信息
    let bvid: String // 视频BVID
    let cover: String // 视频封面
    let desc: String // 视频简介
//    disable_preview num 0
    let duration_text: String // 视频长度文本
    let jump_url: String // 跳转URL
//    stat obj 统计信息
    let title: String // 视频标题
//    type    num    1
}

struct BiliDynamicListItemModuleDynamicMajorDraw: Codable {
    let id: Int // 对应相簿id
    let items: [BiliDynamicListItemModuleDynamicMajorDrawItem] // 图片信息列表
//    type    num    1
}

struct BiliDynamicListItemModuleDynamicMajorDrawItem: Codable {
    let height: Int // 图片高度
    let width: Int // 图片宽度
    let size: Float // 图片大小,单位KB
    let src: String // 图片URL
    // tags    array
}

struct BiliDynamicListItemModuleDynamicMajorLiveRcmd: Codable {
    let content: String // 直播间内容JSON
    let reserve_type: Int
}

struct BiliDynamicListItemModuleDynamicMajorLiveRcmdContent: Codable {
    let type: Int
    let live_play_info: BiliDynamicListItemModuleDynamicMajorLiveRcmdContentInfo
    func getCover() -> String? {
        return self.live_play_info.cover.replace(of: "http://", with: "https://")
    }

    func getTitle() -> String? {
        return self.live_play_info.title
    }
}

struct BiliDynamicListItemModuleDynamicMajorLiveRcmdContentInfo: Codable {
    let title: String
    let cover: String
    let live_id: String
    let live_start_time: Int
    let live_status: Int
    let area_name: String
    let parent_area_name: String
    let link: String
    let room_paid_type: Int
    let uid: Int
}

struct BiliDynamicListItemModuleDynamicMajorArticle: Codable {
    let covers: [String] // 封面图数组,最多三张
    let desc: String
    let id: Int
    let jump_url: String
    let label: String
    let title: String
}
