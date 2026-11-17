//
//  LogBackends.swift
//  Easy Swift
//
//  日志后端：**文件**（导出用的真相源）+ **系统日志**（按 category 过滤）+ **控制台**（真机排错）。
//
//  为什么不能只靠 SwiftUtils 的 `LogExporter`：它读的是 OSLogStore，只有有限窗口，
//  debug 级 os_log 默认不落盘、`isPublic: false` 的内容还是 `<private>` —— 导不出"从启动到现在"的完整日志。
//  所以这里自己写一份按天滚动的日志文件，导出以文件为准。
//
//  真机踩过的坑：
//  - 只切 OSLog 后 `devicectl --console` 里应用日志全消失（真机排错主通道），所以 DEBUG 必须同时写控制台；
//  - `LogBackend` 只给 level/message/metadata，没有 category 参数 —— 分类走 `metadata["category"]`，
//    OSLog 后端按它选 `Logger(category:)`。
//

import Foundation
import os
import SwiftUtils

/// 日志分类：导出时可按分类过滤（`log show --predicate 'category == "parsing"'` 同样有效）
enum LogCategory: String, CaseIterable {
    case app
    case parsing
    case inbox
    case ui
}

/// 把一条日志分发给多个后端
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

/// 系统日志后端：category 从 metadata 里取，按分类建 `Logger` 并缓存
final class CategorizedOSLogBackend: LogBackend, @unchecked Sendable {
    private let subsystem: String
    private let isPublic: Bool
    private let lock=NSLock()
    private var loggers: [String: Logger]=[:]

    init(subsystem: String, isPublic: Bool) {
        self.subsystem=subsystem
        self.isPublic=isPublic
    }

    func log(_ level: LogLevel,
             message: String,
             metadata: [String: String],
             file: String,
             function: String,
             line: UInt)
    {
        let category=metadata["category"] ?? LogCategory.app.rawValue
        let logger: Logger=lock.withLock {
            if let cached=loggers[category] { return cached }
            let created=Logger(subsystem: subsystem, category: category)
            loggers[category]=created
            return created
        }

        var text=message
        if !metadata.isEmpty {
            let extras=metadata.filter { $0.key != "category" }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            if !extras.isEmpty { text += " \(extras)" }
        }

        if isPublic {
            Self.emit(logger, level: level, text: text, public: true)
        } else {
            Self.emit(logger, level: level, text: text, public: false)
        }
    }

    /// OSLog 的隐私标记必须在插值字面量里写死（`.public` / `.private`），
    /// 用变量传会报 "cannot infer contextual base"，所以按 public 分两支。
    private static func emit(_ logger: Logger, level: LogLevel, text: String, public isPublic: Bool) {
        switch level {
        case .trace:
            if isPublic { logger.trace("\(text, privacy: .public)") } else { logger.trace("\(text, privacy: .private)") }
        case .debug:
            if isPublic { logger.debug("\(text, privacy: .public)") } else { logger.debug("\(text, privacy: .private)") }
        case .info:
            if isPublic { logger.info("\(text, privacy: .public)") } else { logger.info("\(text, privacy: .private)") }
        case .notice:
            if isPublic { logger.notice("\(text, privacy: .public)") } else { logger.notice("\(text, privacy: .private)") }
        case .warning:
            if isPublic { logger.warning("\(text, privacy: .public)") } else { logger.warning("\(text, privacy: .private)") }
        case .error:
            if isPublic { logger.error("\(text, privacy: .public)") } else { logger.error("\(text, privacy: .private)") }
        case .critical:
            if isPublic { logger.critical("\(text, privacy: .public)") } else { logger.critical("\(text, privacy: .private)") }
        }
    }
}

/// 文件日志后端：`Application Support/Logs/app-YYYYMMDD.log`，按天滚动、单文件上限、保留 N 天。
///
/// 用同步串行队列写：日志量小（一次会话几百行），简单可靠优先；
/// 写失败只吞掉这一次（不能因为日志失败影响业务，也不能在写日志里再打日志造成递归）。
final class FileLogBackend: LogBackend, @unchecked Sendable {
    static let maxFileSize: Int64=5 * 1024 * 1024
    static let retentionDays=7

    private let directory: URL
    private let queue=DispatchQueue(label: "me.zzhhoo.easyswift.filelog")
    private let lineFormatter: DateFormatter
    private let dayFormatter: DateFormatter

    init(directory: URL) {
        self.directory=directory
        lineFormatter=DateFormatter()
        lineFormatter.dateFormat="yyyy-MM-dd HH:mm:ss.SSS"
        lineFormatter.locale=Locale(identifier: "en_US_POSIX")
        lineFormatter.timeZone=TimeZone(identifier: "Asia/Shanghai")
        dayFormatter=DateFormatter()
        dayFormatter.dateFormat="yyyyMMdd"
        dayFormatter.locale=Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone=TimeZone(identifier: "Asia/Shanghai")

        queue.sync { [self] in
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            pruneOldFiles()
        }
    }

    func log(_ level: LogLevel,
             message: String,
             metadata: [String: String],
             file: String,
             function: String,
             line: UInt)
    {
        let category=metadata["category"] ?? LogCategory.app.rawValue
        let source=(file as NSString).lastPathComponent
        let now=Date()
        let text="[\(lineFormatter.string(from: now))] [\(level.name.uppercased())] [\(category)] \(message) (\(source):\(line))\n"
        guard let data=text.data(using: .utf8) else { return }

        queue.async { [self] in
            append(data, day: dayFormatter.string(from: now))
        }
    }

    // MARK: - 写

    private func append(_ data: Data, day: String) {
        let fileManager=FileManager.default
        var url=directory.appendingPathComponent("app-\(day).log")

        // 单文件超上限就轮转成 .1（只留一份，避免日志把磁盘吃满）
        if let size=(try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64,
           size + Int64(data.count) > Self.maxFileSize
        {
            let rotated=directory.appendingPathComponent("app-\(day).log.1")
            try? fileManager.removeItem(at: rotated)
            try? fileManager.moveItem(at: url, to: rotated)
            url=directory.appendingPathComponent("app-\(day).log")
        }

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        guard let handle=try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // 刻意不打印：写日志失败时再打日志会递归
        }
    }

    // MARK: - 清理

    private func pruneOldFiles() {
        let fileManager=FileManager.default
        guard let files=try? fileManager.contentsOfDirectory(at: directory,
                                                             includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let deadline=Date().addingTimeInterval(-Double(Self.retentionDays) * 86400)
        for file in files where file.lastPathComponent.hasPrefix("app-") {
            let modified=(try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < deadline {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

enum AppLogging {
    /// subsystem 用 bundle id：导出/过滤都按它，和别的 App 不会串
    static let subsystem="me.zzhhoo.easyswift"

    static var logsDirectory: URL {
        let base=FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Logs", isDirectory: true)
    }

    private static var installed=false

    /// 在 App 启动最早期调用一次
    static func install() {
        guard !installed else { return }
        installed=true
        let fileBackend=FileLogBackend(directory: logsDirectory)
        #if DEBUG
        // 调试：控制台（devicectl --console 可见）+ 系统日志 + 文件
        SU.configureLogging(level: .debug,
                            backend: FanOutLogBackend([
                                ConsoleBackend(label: "EasySwift"),
                                CategorizedOSLogBackend(subsystem: subsystem, isPublic: true),
                                fileBackend,
                            ]))
        #else
        // 发布：系统日志（内容私有）+ 文件（导出用）
        SU.configureLogging(level: .info,
                            backend: FanOutLogBackend([
                                CategorizedOSLogBackend(subsystem: subsystem, isPublic: false),
                                fileBackend,
                            ]))
        #endif
    }

    // MARK: - 导出

    /// 日志文件（按天升序），只取最近 `days` 天
    static func logFiles(days: Int = FileLogBackend.retentionDays) -> [URL] {
        let fileManager=FileManager.default
        guard let files=try? fileManager.contentsOfDirectory(at: logsDirectory,
                                                             includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [] }
        let deadline=Date().addingTimeInterval(-Double(days) * 86400)
        return files
            .filter { $0.lastPathComponent.hasPrefix("app-") }
            .filter { file in
                guard let modified=(try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                else { return false }
                return modified >= deadline
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 把最近 N 天日志拼成一份导出文本：头部附环境信息，正文按文件顺序拼接
    static func exportText(days: Int = FileLogBackend.retentionDays) -> String {
        var header: [String]=[]
        header.append("Easy Swift 日志导出")
        header.append("导出时间: \(timestamp())")
        header.append("App 版本: \(AppUtil().getAppVersion()) (\(AppUtil().getAppBuild()))")
        header.append("系统版本: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        header.append("日志窗口: 最近 \(days) 天，共 \(logFiles(days: days).count) 个文件")
        header.append("说明: 已过滤 cookie / token 一类凭据值；行格式 [时间] [级别] [分类] 内容 (文件:行)")
        header.append(String(repeating: "-", count: 60))

        var body: [String]=[]
        for file in logFiles(days: days) {
            guard let text=try? String(contentsOf: file, encoding: .utf8) else { continue }
            body.append("===== \(file.lastPathComponent) =====")
            body.append(desensitize(text))
        }
        if body.isEmpty {
            body.append("（没有日志文件）")
        }
        return (header + body).joined(separator: "\n")
    }

    /// 导出前过滤凭据值：保留键名，值替换成 ***
    static func desensitize(_ text: String) -> String {
        let patterns=[
            #"(?i)(web_session|a1|webid|gid|xsec_token|xsec_source|id_token|access_token|refresh_token|token|cookie|authorization)([=:]\s*)([^;\s&"'\\]+)"#,
        ]
        var result=text
        for pattern in patterns {
            guard let regex=try? NSRegularExpression(pattern: pattern) else { continue }
            let range=NSRange(result.startIndex..., in: result)
            result=regex.stringByReplacingMatches(in: result,
                                                  range: range,
                                                  withTemplate: "$1$2***")
        }
        return result
    }

    private static func timestamp() -> String {
        let formatter=DateFormatter()
        formatter.dateFormat="yyyy-MM-dd HH:mm:ss"
        formatter.locale=Locale(identifier: "en_US_POSIX")
        formatter.timeZone=TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: Date())
    }

    /// 生成可分享的导出文件（临时目录），失败返回 nil
    static func writeExportFile(days: Int = FileLogBackend.retentionDays) -> URL? {
        let text=exportText(days: days)
        let formatter=DateFormatter()
        formatter.dateFormat="yyyyMMdd-HHmmss"
        formatter.locale=Locale(identifier: "en_US_POSIX")
        formatter.timeZone=TimeZone(identifier: "Asia/Shanghai")
        let name="easyswift-log-\(formatter.string(from: Date())).txt"
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            debugPrint(.app, "[日志导出] 写文件失败: \(error.localizedDescription)")
            return nil
        }
    }
}
