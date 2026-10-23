//
//  CrashRecorder.swift
//  Easy Swift
//
//  崩溃留痕：进程被系统杀掉之前，尽量把"发生了什么"写到磁盘；下次启动读出来提示用户。
//
//  先说清能力边界：
//  - 绝大多数崩溃（`SIGABRT` 这类，例如隐私违规被系统直接 abort）**拦不住也恢复不了**，
//    进程已经被终止。这里做的是「记录 + 下次启动提示」，不是"拦截不闪退"。
//  - 信号处理函数里只能用 async-signal-safe 调用：这里只做 `write` 到一个**启动时就打开**的 fd，
//    不分配内存、不打印、不建 FileManager。复杂逻辑会引入二次崩溃。
//

import Foundation
import SwiftUtils

struct CrashReport: Identifiable {
    let id=UUID()
    let date: Date
    let title: String
    let details: String
}

final class CrashRecorder {
    static let shared = CrashRecorder()

    /// 信号处理里要用的 fd：启动时打开好，处理函数里只 write
    /// （用 static 是必须的：@convention(c) 的闭包不能捕获上下文）
    private static var signalFileDescriptor: Int32 = -1
    private static var signalFilePath: String = ""

    private let directory: URL
    private let exceptionFile: URL
    private let signalFile: URL

    private init() {
        let base=FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory=base.appendingPathComponent("crash", isDirectory: true)
        exceptionFile=directory.appendingPathComponent("pending-exception.json")
        signalFile=directory.appendingPathComponent("pending-signal.bin")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - 安装

    func install() {
        NSSetUncaughtExceptionHandler { exception in
            CrashRecorder.shared.record(exception: exception)
        }
        installSignalHandlers()
        debugPrint("[崩溃记录] 已安装，目录=\(directory.lastPathComponent)")
    }

    private func installSignalHandlers() {
        Self.signalFilePath=signalFile.path
        // 注意：**不要**用 O_TRUNC —— 启动时截断会把上次崩溃留下的记录清掉，
        // 结果就是"永远弹不出提示"。追加写即可，读完由 takePendingReport 删除。
        Self.signalFileDescriptor=open(Self.signalFilePath, O_WRONLY | O_CREAT | O_APPEND, 0o600)

        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig) { received in
                // async-signal-safe：只写 16 字节（4 字节信号 + 8 字节时间戳 + 4 字节填充）
                if CrashRecorder.signalFileDescriptor >= 0 {
                    var record=[UInt8](repeating: 0, count: 16)
                    var code=Int32(received)
                    var stamp=Int64(time(nil))
                    withUnsafeBytes(of: &code) { raw in
                        for (offset, byte) in raw.enumerated() { record[offset]=byte }
                    }
                    withUnsafeBytes(of: &stamp) { raw in
                        for (offset, byte) in raw.enumerated() { record[4 + offset]=byte }
                    }
                    _=record.withUnsafeBytes { buffer in
                        write(CrashRecorder.signalFileDescriptor, buffer.baseAddress, buffer.count)
                    }
                }
                // 交回默认处理，让它照常终止（我们不假装能恢复）
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    // MARK: - 写入

    private func record(exception: NSException) {
        let payload: [String: Any] = [
            "date": Date().timeIntervalSince1970,
            "name": exception.name.rawValue,
            "reason": exception.reason ?? "",
            "stack": exception.callStackSymbols,
        ]
        if let data=try? JSONSerialization.data(withJSONObject: payload),
           let text=String(data: data, encoding: .utf8)
        {
            try? text.write(to: exceptionFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - 读取（下次启动）

    /// 取回上次的崩溃并**清掉**，保证只提示一次
    func takePendingReport() -> CrashReport? {
        if let report=takeExceptionReport() {
            return report
        }
        return takeSignalReport()
    }

    private func takeExceptionReport() -> CrashReport? {
        guard let text=try? String(contentsOf: exceptionFile, encoding: .utf8),
              let data=text.data(using: .utf8),
              let payload=(try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        defer { try? FileManager.default.removeItem(at: exceptionFile) }

        let stamp=payload["date"] as? TimeInterval ?? 0
        let name=payload["name"] as? String ?? "未知异常"
        let reason=payload["reason"] as? String ?? ""
        let stack=(payload["stack"] as? [String] ?? []).prefix(6).joined(separator: "\n")
        return CrashReport(date: Date(timeIntervalSince1970: stamp),
                           title: "上次因异常退出（\(name)）",
                           details: reason + (stack.isEmpty ? "" : "\n\n" + stack))
    }

    private func takeSignalReport() -> CrashReport? {
        guard let data=try? Data(contentsOf: signalFile), data.count >= 12 else { return nil }
        // 读完**清空而不是删除**：信号处理器写的是启动时打开的 fd，
        // 文件被 unlink 之后 fd 指向的还是那个"看不见的 inode"，下一次崩溃就会写丢。
        defer {
            if Self.signalFileDescriptor >= 0 {
                ftruncate(Self.signalFileDescriptor, 0)
            }
        }

        // 必须用 loadUnaligned：记录里 Int64 落在偏移 4，按 8 字节对齐读会直接 trap
        // （踩过一次：Swift/UnsafeRawPointer.swift:450 Fatal error: load from misaligned raw pointer）
        let code=data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: Int32.self) }
        let stamp=data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
        let name=Self.signalName(code)
        return CrashReport(date: Date(timeIntervalSince1970: TimeInterval(stamp)),
                           title: "上次闪退（\(name)）",
                           details: "收到信号 \(code)（\(name)）。\n这类崩溃通常发生在系统强制终止进程时（例如权限、内存、断言失败），进程无法恢复。")
    }

    private static func signalName(_ code: Int32) -> String {
        switch code {
        case SIGABRT: return "SIGABRT，通常是断言失败或被系统终止"
        case SIGSEGV: return "SIGSEGV，野指针/内存访问越界"
        case SIGBUS: return "SIGBUS，内存对齐或映射错误"
        case SIGILL: return "SIGILL，非法指令"
        case SIGFPE: return "SIGFPE，算术异常"
        case SIGTRAP: return "SIGTRAP，调试陷阱"
        default: return "未知信号"
        }
    }
}
