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
//    @AppStorage("bili_dynamic_image_mode") var isDynamicShowImage: Bool = true
//    @AppStorage("open_web_in_app") var openWebInApp: Bool = false
    @AppStorage("github_username") var GithubUsername: String = ""
    @AppStorage("github_access_token") var GithubAccessToken: String = ""
    @AppStorage("tikhub_token") var TikhubToken: String = ""
    @State private var showingAlert = false
    @State private var alertTitle: String = "未知错误"
    @State private var alertText: String = "未知错误"
    var body: some View {
        VStack {
            List {
                //                Section(header: Text("动态")) {
                //                    Toggle(isOn: $isDynamicShowImage) {
                //                        Text("动态是否显示图片")
                //                    }
                //                }
                //                Section(header: Text("网页")) {
                //                    Toggle(isOn: $openWebInApp) {
                //                        Text("使用Bilibili app打开网页")
                //                    }
                //                }
                Section(header: Text("哔了个哩")) {
                    Button(action: {
                        alertTitle = "你要清空哔哩哔哩功能的登录数据吗？"
                        alertText = "仅用于开发测试"
                        showingAlert = true
                    }) {
                        Text("清空哔哩哔哩登录数据")
                    }
                    .alert(alertTitle, isPresented: $showingAlert) {
                        Button("清空", action: {
                            BiliLoginService().removeCookie()
//                            print("清空登录数据" + setSu.string(trueStr: "成功", falseStr: "失败"))
                        })
                        Button("No", action: {})
                    } message: {
                        Text(alertText)
                    }
                }
                Section(header: Text("Github（自动保存）")) {
                    TextField("用户名", text: $GithubUsername)
                    SecureField("Access Token", text: $GithubAccessToken)
                }
                Section(header: Text("Tikhub（自动保存）")) {
                    TextField("Token", text: $TikhubToken)
                }
                if let appIcon = getAppIconImage() {
                    AppIconAndNameView(image: appIcon)
                } else {
                    Text("Failed to load app icon")
                }
                Section(header: Text("About")) {
                    TextItem(title: "开发者", detail: "zhihaofans")
                    TextItem(title: "Version", detail: "\(AppUtil().getAppVersion()) (\(AppUtil().getAppBuild()))" /* "0.0.1" */ )
                }
//                Section(header: Text("Bilibili")) {
//                    TextItem(title: "安装哔哩哔哩", detail: AppService().isAppIntalled().string(trueStr: "已安装", falseStr: "未安装"))
//                }
//                if LoginService().isLogin() {
//                    Section(header: Text("登录数据(请不要给别人看⚠️)")) {
//                        TextItem(title: "Cookies", detail: LoginService().getCookiesString())
//                    }
//                }
            }
            // Text("这里是设置").font(.largeTitle)
        }
        #if os(iOS)
        .navigationBarTitle("设置", displayMode: .inline)
        #else
        .navigationTitle("设置")
        #endif
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
