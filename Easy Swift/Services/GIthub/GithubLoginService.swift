//
//  GithubLoginService.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import Foundation
import SwiftUtils

class GithubLoginService {
    func isLogin() -> Bool {
        return UserDefaultUtil().getString(key: "github_access_token", defaultValue: "").isNotEmpty
    }

    func setUserName(_ name: String) {
        UserDefaultUtil().setString(key: "github_username", value: name)
    }

    func getUserName() -> String {
        return UserDefaultUtil().getString(key: "github_username", defaultValue: "")
    }

    func setAccessToken(_ token: String) {
        UserDefaultUtil().setString(key: "github_access_token", value: token)
    }

    func getAccessToken() -> String {
        return UserDefaultUtil().getString(key: "github_access_token", defaultValue: "")
    }
}
