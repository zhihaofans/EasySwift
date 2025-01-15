//
//  GithubTrendingModel.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/14.
//

import Foundation

struct GithubTrendingResult: Codable {
    let total_count: Int
    let incomplete_results: Bool
    let items: [GithubTrendingItem]
}

struct GithubTrendingItem: Codable {
    let id: Int
    let name: String
    let full_name: String
    let description: String
    let html_url: String
    let stargazers_count: Int
    let forks_count: Int
    let language: String?
    let owner: GithubTrendingItemOwner
    let license: GithubTrendingItemLicense?
}

struct GithubTrendingItemLicense: Codable {
    let key: String
    let name: String
    let spdx_id: String
    let url: String?
    let node_id: String
}

struct GithubTrendingItemOwner: Codable {
    let login: String
    let id: Int
    let avatar_url: String
    let html_url: String
    let type: String
}
