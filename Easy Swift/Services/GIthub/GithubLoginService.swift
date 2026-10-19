//
//  GithubLoginService.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import Foundation
import SwiftUtils

/// GitHub 登录信息。
/// - 用户名：非机密，存 UserDefaults（设置页仍用 @AppStorage 直绑）。
/// - Access Token：凭据，存钥匙串；旧版本曾用 UserDefaults 明文保存，首次访问时自动迁移。
class GithubLoginService {
    private static let tokenKey="github_access_token"
    private static let userNameKey="github_username"

    private let keychain=KeychainUtil()
    private let defaults=UserDefaults.standard

    /// 迁移只做一次（这个类型在 View 里是存储属性，会随 body 重算反复构造）
    private static var didMigrateToken=false

    init() {
        if !Self.didMigrateToken {
            Self.didMigrateToken=true
            migrateTokenFromUserDefaultsIfNeeded()
        }
    }

    // MARK: - 用户名（非机密）

    func setUserName(_ name: String) {
        defaults.set(name, forKey: Self.userNameKey)
    }

    func getUserName() -> String {
        return defaults.string(forKey: Self.userNameKey) ?? ""
    }

    // MARK: - Access Token（钥匙串）

    func isLogin() -> Bool {
        return getAccessToken().isNotEmpty
    }

    /// 保存 Token。传空串等于退出登录。
    /// - Returns: 是否写入成功；失败时保留旧值不动，调用方可据此提示用户。
    @discardableResult
    func setAccessToken(_ token: String) -> Bool {
        let trimmed=token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            _ = keychain.remove(forKey: Self.tokenKey)
            return true
        }
        if keychain.saveString(forKey: Self.tokenKey, value: trimmed) {
            return true
        }
        // 写失败不能假装成功：否则界面显示"已登录"，下次启动却读不回来
        SU.log.error("保存 GitHub Access Token 到钥匙串失败")
        return false
    }

    func getAccessToken() -> String {
        return keychain.getString(forKey: Self.tokenKey) ?? ""
    }

    // MARK: - 旧数据迁移

    /// 旧版本把 token 明文放在 UserDefaults。这里搬到钥匙串，成功后删除明文。
    /// 迁移失败时**保留明文**，宁可暂时不安全，也不要把用户的 token 弄丢。
    private func migrateTokenFromUserDefaultsIfNeeded() {
        guard let legacy=defaults.string(forKey: Self.tokenKey), legacy.isNotEmpty else { return }
        if keychain.getString(forKey: Self.tokenKey) == nil {
            guard keychain.saveString(forKey: Self.tokenKey, value: legacy) else {
                SU.log.error("迁移旧 Token 到钥匙串失败，暂时保留 UserDefaults 中的明文")
                return
            }
            SU.log.info("已把旧 Token 迁移到钥匙串")
        }
        defaults.removeObject(forKey: Self.tokenKey)
    }
}
