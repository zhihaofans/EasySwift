//
//  ParseBudgetTests.swift
//  Easy SwiftTests
//
//  超时/重试的判定逻辑：这层错了表现为"风控也重试三遍"或"网络抖一下直接失败"。
//

import Foundation
import Testing
import SwiftUtils

@testable import Easy_Swift

struct ParseBudgetTests {
    @Test func retryableErrors() {
        #expect(ParseBudget.isRetryable(LinkParseError.network))
        #expect(ParseBudget.isRetryable(TimeoutError()))
        #expect(ParseBudget.isRetryable(URLError(.timedOut)))
        #expect(ParseBudget.isRetryable(URLError(.networkConnectionLost)))
    }

    /// 风控/登录墙/内容不存在重试只会让用户多等
    @Test func nonRetryableErrors() {
        #expect(!ParseBudget.isRetryable(LinkParseError.blocked))
        #expect(!ParseBudget.isRetryable(LinkParseError.needLogin))
        #expect(!ParseBudget.isRetryable(LinkParseError.notFound))
        #expect(!ParseBudget.isRetryable(LinkParseError.emptyResult))
        #expect(!ParseBudget.isRetryable(LinkParseError.unsupported))
        #expect(!ParseBudget.isRetryable(URLError(.badURL)))
    }

    @Test func retryPolicyDelays() {
        let policy=ParseBudget.networkRetry
        #expect(policy.maxAttempts == 3)
        #expect(policy.delay(forAttempt: 1) == 0.6)
        #expect(policy.delay(forAttempt: 2) == 1.2)
        #expect(policy.delay(forAttempt: 3) == nil)
    }

    @Test func runReturnsImmediatelyOnSuccess() async throws {
        let value=try await ParseBudget.run { 42 }
        #expect(value == 42)
    }

    @Test func runRetriesThenSucceeds() async throws {
        let counter=Counter()
        let value=try await ParseBudget.run(policy: RetryPolicy(maxAttempts: 3, baseDelay: 0.01, multiplier: 2, maxDelay: 0.02)) {
            if counter.bump() < 3 { throw LinkParseError.network }
            return 7
        }
        #expect(value == 7)
        #expect(counter.value == 3)
    }

    @Test func runGivesUpAfterMaxAttempts() async {
        let counter=Counter()
        do {
            _=try await ParseBudget.run(policy: RetryPolicy(maxAttempts: 3, baseDelay: 0.01, multiplier: 2, maxDelay: 0.02)) {
                _=counter.bump()
                throw LinkParseError.network
            }
            Issue.record("一直失败却没有抛错")
        } catch let error as LinkParseError {
            #expect(error == .network)
            #expect(counter.value == 3)
        } catch {
            Issue.record("得到意外错误 \(error)")
        }
    }

    @Test func runDoesNotRetryBlocked() async {
        let counter=Counter()
        do {
            _=try await ParseBudget.run {
                _=counter.bump()
                throw LinkParseError.blocked
            }
            Issue.record("blocked 却没有抛错")
        } catch let error as LinkParseError {
            #expect(error == .blocked)
            #expect(counter.value == 1)
        } catch {
            Issue.record("得到意外错误 \(error)")
        }
    }

    /// 超时要映射成网络错误，且不能在超时后再重试
    @Test func runMapsTimeoutToNetworkWithoutRetry() async {
        let counter=Counter()
        let started=Date()
        do {
            _=try await ParseBudget.run(timeout: 0.15) {
                _=counter.bump()
                try await Task.sleep(for: .seconds(3))
                return 1
            }
            Issue.record("超时却没有抛错")
        } catch let error as LinkParseError {
            #expect(error == .network)
            #expect(counter.value == 1)
            #expect(Date().timeIntervalSince(started) < 1.0)
        } catch {
            Issue.record("得到意外错误 \(error)")
        }
    }
}

/// 测试用的线程安全计数器
final class Counter: @unchecked Sendable {
    private let lock=NSLock()
    private var n=0

    @discardableResult
    func bump() -> Int {
        lock.lock(); defer { lock.unlock() }
        n += 1
        return n
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return n
    }
}
