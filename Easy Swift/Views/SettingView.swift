//
//  SettingView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/1.
//

import SwiftUI
import SwiftUtils

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SettingView: View {
//    @AppStorage("open_web_in_app") var openWebInApp: Bool = false
    @State private var showingAlert = false
    @State private var alertTitle: String = "未知错误"
    @State private var alertText: String = "未知错误"
    // 小红书登录态
    @State private var showingXhsLogin = false
    /// 扫码登录面板（原生二维码）；失败/超时由用户点「改用网页登录」退回 showingXhsLogin
    @State private var showingXhsQRLogin = false
    @State private var showingXhsCookieEdit = false
    @State private var xhsState: XiaohongshuLoginState = .unknown
    var body: some View {
        VStack {
            List {
                //                Section(header: Text("动态")) {
                //                    Toggle(isOn: $isDynamicShowImage) {
                //                        Text("动态是否显示图片")
                //                    }
                //                }

                if let appIcon = getAppIconImage() {
                    AppIconAndNameView(image: appIcon)
                } else {
                    Text("Failed to load app icon")
                }
                Section(header: Text("账号")) {
                    HStack {
                        Text("小红书")
                        Spacer()
                        Text(xhsStateText)
                            .foregroundStyle(xhsState == .expired ? Color.orange : Color.secondary)
                    }
                    if xhsState == .valid || xhsState == .expired {
                        Button("退出登录", role: .destructive) {
                            Task {
                                await XiaohongshuSession.shared.clear()
                                await refreshXhsLoginState()
                            }
                        }
                    }
                    if xhsState != .valid {
                        Button(xhsState == .expired ? "重新登录" : "登录小红书") {
                            // macOS 上扫码最顺（用手机扫电脑屏幕）；iPhone 上没法扫自己这块屏，
                            // 所以手机端仍以网页登录（手机号/验证码）为主，扫码放到次要入口
                            #if os(macOS)
                            showingXhsQRLogin = true
                            #else
                            showingXhsLogin = true
                            #endif
                        }
                        #if os(iOS)
                        Button("扫码登录（用另一台设备扫）") {
                            showingXhsQRLogin = true
                        }
                        #endif
                    }
                    Button("手动填写 Cookie") {
                        showingXhsCookieEdit = true
                    }
                    Text("网页登录被滑块卡住时，可以从浏览器复制 cookie 粘进来。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section(header: Text("About")) {
                    TextItem(title: "开发者", detail: "zhihaofans")
                    TextItem(title: "Version", detail: "\(AppUtil().getAppVersion()) (\(AppUtil().getAppBuild()))" /* "0.0.1" */ )
                }
            }
            // Text("这里是设置").font(.largeTitle)
        }
        #if os(iOS)
        .navigationBarTitle("设置", displayMode: .inline)
        #else
        .navigationTitle("设置")
        #endif
        .task {
            await refreshXhsLoginState()
        }
        .sheet(isPresented: $showingXhsQRLogin) {
            XhsQRLoginView(onFinished: {
                Task { await refreshXhsLoginState() }
            }, onFallback: {
                // 二维码这条路走不通（页面改版/风控/用户扫不上）就退回可见网页登录
                showingXhsLogin = true
            })
        }
        .sheet(isPresented: $showingXhsLogin) {
            XhsLoginView(onFinished: {
                Task { await refreshXhsLoginState() }
            })
        }
        .sheet(isPresented: $showingXhsCookieEdit) {
            XhsCookieEditView(onSaved: {
                Task { await refreshXhsLoginState() }
            })
        }
    }

    /// 登录态以"钥匙串里有没有 cookie"为准；真伪在解析时会由行为探测兜底
    @MainActor
    private var xhsStateText: String {
        switch xhsState {
        case .valid: return "已登录"
        case .expired: return "登录已过期"
        case .unknown: return "未登录"
        }
    }

    /// 状态以「探测结果」为准：有 cookie 不代表能用，过期了要能说出来
    @MainActor
    private func refreshXhsLoginState() async {
        xhsState = await XiaohongshuSession.shared.refreshState()
    }

    // MARK: - App 图标获取（跨平台）

    // iOS：从 Info.plist 的 CFBundleIcons 中取图标名称
    private func getAppIconName() -> String? {
        #if os(iOS)
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last
        {
            return lastIcon
        }
        return nil
        #else
        // macOS 不使用名称方式（直接从 NSApplication 取图标）
        return nil
        #endif
    }

    // [UPDATED] 返回跨平台图片类型
    private func getAppIconImage() -> PlatformImage? {
        #if os(iOS)
        if let iconName = getAppIconName() {
            return UIImage(named: iconName)
        }
        return nil
        #elseif os(macOS)
        // macOS：系统级获取当前 App 图标最稳
        return NSApplication.shared.applicationIconImage
        #endif
    }
}

struct AppIconAndNameView: View {
    let image: PlatformImage
    var body: some View {
        VStack(alignment: .center) {
            #if os(iOS)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 5)
            #elseif os(macOS)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 5)
            #endif

            Text(AppUtil().getAppName())
                .font(.title)
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TextItem: View {
    var title: String
    var detail: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(detail).foregroundColor(.gray)
        }
    }
}

#Preview {
    SettingView()
}
