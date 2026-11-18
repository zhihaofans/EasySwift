//
//  PermissionMappingTests.swift
//  Easy SwiftTests
//
//  权限状态 → 错误文案的映射。这层错了用户会被引导去看"设置"，而实际是工程缺 Info.plist 键。
//

import Testing
import SwiftUtils

@testable import Easy_Swift

struct PermissionMappingTests {
    @Test func authorizedStatesCanSave() {
        #expect(PhotoLibrarySaver.accessError(for: .authorized) == nil)
        #expect(PhotoLibrarySaver.accessError(for: .limited) == nil)
    }

    @Test func deniedStatesTellUserToOpenSettings() {
        #expect(PhotoLibrarySaver.accessError(for: .denied) == .permissionDenied)
        #expect(PhotoLibrarySaver.accessError(for: .notDetermined) == .permissionDenied)
    }

    @Test func restrictedIsNotFixableByUser() {
        #expect(PhotoLibrarySaver.accessError(for: .restricted) == .permissionRestricted)
        #expect(!MediaSaveError.permissionRestricted.localizedDescription.contains("隐私与安全性"))
    }

    @Test func unavailablePlatform() {
        #expect(PhotoLibrarySaver.accessError(for: .unavailable) == .libraryUnavailable)
        #expect(PhotoLibrarySaver.accessError(for: .unknown) == .libraryUnavailable)
    }

    /// 0.0.33 新增：缺 Info.plist 用法说明是工程配置问题，不能提示用户去设置
    @Test func misconfiguredPointsToInfoPlist() {
        #expect(PhotoLibrarySaver.accessError(for: .misconfigured) == .permissionMisconfigured)
        let message=MediaSaveError.permissionMisconfigured.localizedDescription
        #expect(message.contains("Info.plist"))
        #expect(!message.contains("设置 → 隐私与安全性"))
    }

    @Test func allPermissionProblemsStopBatchSaving() {
        #expect(MediaSaveError.permissionDenied.isPermissionProblem)
        #expect(MediaSaveError.permissionRestricted.isPermissionProblem)
        #expect(MediaSaveError.libraryUnavailable.isPermissionProblem)
        #expect(MediaSaveError.permissionMisconfigured.isPermissionProblem)
        #expect(!MediaSaveError.invalidImage.isPermissionProblem)
        #expect(!MediaSaveError.downloadFailed("x").isPermissionProblem)
    }
}
