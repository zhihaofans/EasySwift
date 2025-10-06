//
//  AppService.swift
//  Bili-Swift
//
//  Created by zzh on 2024/7/17.
//

import Foundation
import SwiftUI
import SwiftUtils

// iOS 用 UIKit，macOS 用 AppKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class BiliAppService {
    @AppStorage("open_web_in_app") private var openWebInApp = false
    func getBiliUrl(_ url: String) -> String {
        // return "bilibili://browser/?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""))"
        return "bilibili://browser/?url=" + url
    }

    func openAppUrl(_ urlStr: String) {
        let biliUrl = self.getBiliUrl(urlStr)
        guard biliUrl.isNotEmpty, let url = URL(string: biliUrl) else { return }

        // [UPDATED] 使用 MainActor 确保主线程操作（多平台安全）
        Task { @MainActor in
            #if os(iOS)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }

    /// [UPDATED] 新方法：检测是否安装 B 站 App（多平台实现）
    func isAppInstalled() -> Bool {
        #if os(iOS)
        // 仍然使用你项目里的 AppUtil（iOS 上可行）
        return AppUtil().canOpenUrl("bilibili://")
        #elseif os(macOS)
        // macOS：通过 NSWorkspace 判断是否有可处理 bilibili:// 的 App
        guard let testURL = URL(string: "bilibili://") else { return false }
        return NSWorkspace.shared.urlForApplication(toOpen: testURL) != nil
        #else
        return false
        #endif
    }

    /// [UPDATED] 旧方法保留以兼容旧代码；内部转调新方法
    @available(*, deprecated, message: "Use isAppInstalled() instead.")
    func isAppIntalled() -> Bool { // 注意：原拼写保留（Intalled）
        return self.isAppInstalled() // [UPDATED]
    }

    /// 打开链接：优先 App（当 open_web_in_app = true 且已安装），否则系统浏览器
    func openUrl(appUrl: String, webUrl: String) {
        guard appUrl.isNotEmpty || webUrl.isNotEmpty else { return }

        // [UPDATED] 主线程执行所有打开动作
        Task { @MainActor in
            let appInstalled = self.isAppInstalled() // [UPDATED] 统一新方法
            if self.openWebInApp, appInstalled, appUrl.isNotEmpty {
                // 走 App Scheme
                self.openAppUrl(appUrl)
            } else if webUrl.isNotEmpty, let url = URL(string: webUrl) {
                // 走系统浏览器
                #if os(iOS)
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        }
    }

    func checkLink(_ url: String?) -> String {
        var urlStr = url ?? ""
        if urlStr.starts(with: "//") {
            urlStr = "https:" + urlStr
        }
        if urlStr.starts(with: "http://") {
            urlStr = urlStr.replace(of: "http://", with: "https://")
        }
        return urlStr
    }
}
