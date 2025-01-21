//
//  GithubUserModel.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import Foundation

struct GithubStarsListItem: Codable {
    let id: Int
    let name: String
    let full_name: String
    let description: String
    let html_url: String
    let stargazers_count: Int
    let forks_count: Int
    let language: String
    let owner: GithubTrendingItemOwner
    let license: GithubTrendingItemLicense?
}
