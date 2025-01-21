//
//  SettingView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/1.
//

import SwiftUI
import SwiftUtils
import UIKit

struct SettingView: View {
//    @AppStorage("bili_dynamic_image_mode") var isDynamicShowImage: Bool = true
//    @AppStorage("open_web_in_app") var openWebInApp: Bool = false
    @AppStorage("github_username") var GithubUsername: String = ""
    @AppStorage("github_access_token") var GithubAccessToken: String = ""
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

    private func getAppIconName() -> String? {
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last
        {
            return lastIcon
        }
        return nil
    }

    private func getAppIconImage() -> UIImage? {
        if let iconName = getAppIconName() {
            return UIImage(named: iconName)
        }
        return nil
    }
}

struct AppIconAndNameView: View {
    let image: UIImage
    var body: some View {
        VStack(alignment: .center) {
            // Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            Image(uiImage: image)
                .resizable() // 允许图片可调整大小
                .scaledToFit() // 图片将等比缩放以适应框架
                .frame(width: 120, height: 120) // 设置视图框架的大小
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // 设置圆角矩形形状
                .shadow(radius: 5) // 添加阴影以增强效果
            // .overlay(Circle().stroke(Color.gray, lineWidth: 4)) // 可选的白色边框
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 100, height: 100)
            Text(AppUtil().getAppName())
                .font(.title)
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .center) // 设置对齐方式
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
