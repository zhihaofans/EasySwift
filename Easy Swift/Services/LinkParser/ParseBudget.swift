//
//  ParseBudget.swift
//  Easy Swift
//
//  解析的**时限与重试**集中在这里。
//
//  为什么要有这个文件：以前 18s 的 WebView 等待、20s 的 HTTP 超时、10s 的 HEAD 超时
//  散在各个解析器里，改一个要翻三个文件，而且没有"整次解析最多等多久"的兜底 ——
//  最坏情况是 HTTP 20s + WebView 18s 顺序叠加，用户对着转圈等半分钟。
//
//  规则：
//  - 单个请求 / 单次等待的上限在这里定义，解析器里不许再写魔法数字；
//  - `wholeParse` 是兜底：整次解析超过它就没必要再等了（重试也在它之内）；
//  - 只有**可恢复**的网络错误才重试，风控/登录墙/内容不存在重试也是白搭。
//

import Foundation
import SwiftUtils

enum ParseBudget {
    /// 单次页面 GET 的上限（小红书/抖音 HTTP 路线都走它）
    static let httpRequest: TimeInterval=12
    /// 抖音隐藏 WebView 等页面就绪的上限
    static let webViewReady: TimeInterval=18
    /// 单次 JS 求值的上限（WebView 卡住时别把整轮拖死）
    static let jsEvaluation: TimeInterval=3
    /// 整次解析的兜底上限（含重试）。超过就报网络错误，不让 UI 无限转圈
    static let wholeParse: TimeInterval=45
    /// **装饰性**请求的上限（分享者昵称、sec_uid 这类"有更好、没有也能用"的信息）。
    /// 实测小红书昵称接口会跳验证码页并拖到 26 秒，不能让它决定整次解析的耗时。
    static let decoration: TimeInterval=4

    /// 网络抖动重试：最多 3 次，0.6s → 1.2s
    static let networkRetry=RetryPolicy(maxAttempts: 3, baseDelay: 0.6, multiplier: 2, maxDelay: 4)

    /// 只对"再试一次可能就好了"的错误重试。
    /// 风控（blocked）、登录墙（needLogin）、内容不存在（notFound）、解析不出内容（emptyResult）
    /// 都属于"再试一次也这样"，重试只会让用户多等。
    static func isRetryable(_ error: Error) -> Bool {
        if let parseError=error as? LinkParseError {
            switch parseError {
            case .network: return true
            case .unsupported, .needLogin, .blocked, .notFound, .emptyResult, .unknown: return false
            }
        }
        if error is TimeoutError { return true }
        if let urlError=error as? URLError {
            return [.timedOut, .networkConnectionLost, .cannotConnectToHost,
                    .notConnectedToInternet, .dnsLookupFailed].contains(urlError.code)
        }
        return false
    }
}

extension ParseBudget {
    /// 统一执行器：整次时限 + 可恢复错误重试。
    ///
    /// 抽成函数而不是写在注册表里，是为了能用假操作测：正常返回 / 失败两次后成功 /
    /// 一直失败 / 超时 / 不该重试的错误（风控）各一条。
    ///
    /// - Parameters:
    ///   - timeout: 单次尝试的时限（默认整次解析上限）
    ///   - policy: 重试策略，`delay(forAttempt:)` 返回 nil 表示不再重试
    ///   - onRetry: 即将重试时回调（第几次尝试），用于给 UI 报进度
    static func run<T: Sendable>(
        timeout: TimeInterval = ParseBudget.wholeParse,
        policy: RetryPolicy = ParseBudget.networkRetry,
        onRetry: @Sendable (Int) -> Void = { _ in },
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var attempt=1
        while true {
            do {
                return try await withTimeout(timeout, operation: operation)
            } catch let timeoutError as TimeoutError {
                // 超时不重试：重试只会让用户再等一轮同样的时间
                debugPrint(.parsing, "[解析] 超过 \(Int(timeout))s 未完成，放弃（\(timeoutError)）")
                throw LinkParseError.network
            } catch {
                guard isRetryable(error), let delay=policy.delay(forAttempt: attempt) else { throw error }
                debugPrint(.parsing, "[解析] 第 \(attempt) 次失败（\(error.localizedDescription)），\(String(format: "%.1f", delay))s 后重试")
                onRetry(attempt + 1)
                try? await Task.sleep(for: .seconds(delay))
                attempt += 1
            }
        }
    }
}

/// 把非 Sendable 的返回包一层，供 `withTimeout` 使用（它要求 `T: Sendable`）
struct SendableBox<Value>: @unchecked Sendable {
    let value: Value
}
