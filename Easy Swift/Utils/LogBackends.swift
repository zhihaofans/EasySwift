//
//  LogBackends.swift
//  Easy Swift
//
//  日志后端组合。SwiftUtils 0.0.33 起后端可插拔，但一次只能配一个；
//  App 的真实需求是**两处都要看**：
//
//  - `ConsoleBackend`（stderr）：`xcrun devicectl device process launch --console` 能看到，
//    这是本项目真机排错的主通道；
//  - `OSLogBackend`（unified log）：可按 subsystem 过滤、能用 `LogExporter` 导出、
//    Console.app 里能回看历史。
//
//  实测（2026-11-18 真机）：只切 OSLog 之后 `--console` 里就只剩系统的两三行，
//  应用日志全没了 —— 排错通道直接失效。所以 DEBUG 用双写，RELEASE 只写系统日志。
//

import Foundation
import SwiftUtils

/// 把一条日志分发给多个后端（等级过滤与格式化由 `LogUtil` 统一做完，这里只做转发）
final class FanOutLogBackend: LogBackend, @unchecked Sendable {
    private let backends: [any LogBackend]

    init(_ backends: [any LogBackend]) {
        self.backends=backends
    }

    func log(_ level: LogLevel,
             message: String,
             metadata: [String: String],
             file: String,
             function: String,
             line: UInt)
    {
        for backend in backends {
            backend.log(level, message: message, metadata: metadata, file: file, function: function, line: line)
        }
    }
}

enum AppLogging {
    /// subsystem 用 bundle id：`LogExporter` 导出时按它过滤，和别的 App 不会串
    static let subsystem="me.zzhhoo.easyswift"
    static let category="app"

    /// 在 App 启动最早期调用一次
    static func install() {
        #if DEBUG
        // 调试：控制台（devicectl --console）+ 系统日志双写；isPublic 让内容不被 `<private>` 遮住
        SU.configureLogging(level: .debug,
                            backend: FanOutLogBackend([
                                ConsoleBackend(label: "EasySwift"),
                                OSLogBackend(subsystem: subsystem, category: category, isPublic: true),
                            ]))
        #else
        // 发布：只写系统日志，内容默认私有（日志里会有 URL / 标题等用户数据）
        SU.configureLogging(level: .info,
                            backend: OSLogBackend(subsystem: subsystem, category: category, isPublic: false))
        #endif
    }
}
