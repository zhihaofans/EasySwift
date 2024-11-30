//
//  BiliMainView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/26.
//

import SwiftUI
import SwiftUtils

struct BiliMainView: View {
    @State private var showingAlert = false
    @State private var alertTitle: String = "未知错误"
    @State private var alertText: String = "未知错误"
    @State private var qrcodeContent: String = ""
    @State private var isLogin = false
    var body: some View {
        VStack {
//            Form {
//                Section(header: Text("输入二维码文本")) {
//                    TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: self.$qrcodeContent)
//                    Button(action: {}) {
//                        Text("登录")
//                    }
//                }
//            }

            if isLogin {
                // TODO: 已登录
            } else {
//                Text("未登录").font(.largeTitle)
                BiliLoginView()
            }
        }
        .onAppear {
            isLogin = BiliLoginService().isLogin()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                self.alertTitle = ""
                self.alertText = ""
                self.showingAlert = false
            })
        } message: {
            Text(self.alertText)
        }
        .setNavigationTitle("哔了个哩")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Text("设置")
                }
            }
        }
    }
}

struct BiliLoginView: View {
    @State private var showingAlert = false
    @State private var alertText: String = "未知错误"
    @State private var loginDataLoaded = false
    @State private var loginUrl: String = ""
    @State private var qrcodeKey: String = ""
    @State private var qrcodeText: String = "等待获取登录链接"
    private let loginService = BiliLoginService()
    var body: some View {
        VStack {
//            Button(action: {
//                print("loadLoginDataFinished:\(loginDataLoaded)")
//                print("loginUrl:\(loginUrl)")
//            }) {
//                Text("重新加载").font(.title)
//            }
//            .padding()
            if !loginDataLoaded {
                Text(qrcodeText)
            } else {
                let qrcodeUrl = "https%3A%2F%2Fpassport.bilibili.com%2Fh5-app%2Fpassport%2Flogin%2Fscan%3Fnavhide%3D1%26from%3D%26qrcode_key%3D\(qrcodeKey)"
                let qrImage = QrcodeUtil().generateQRCode(from: EncodeUtil().urlDecode(qrcodeUrl))
                if qrImage == nil {
                    Text("请安装APP")

                } else {
                    Image(uiImage: qrImage!).resizable().frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 100)
                }
                Button(action: {
                    Task {
                        // 在这里执行耗时的任务
                        AppUtil().openUrl(qrcodeUrl)
                        // 完成后，在主线程更新 UI
//                            DispatchQueue.main.async {
//                                // 更新 UI
//                                print("打开app：" + openSu.string(trueStr: "Su", falseStr: "fail"))
//                            }
                    }
                }) {
                    Text("打开App登录").font(.title)
                }
                .padding()

                Button(action: {
                    self.loginService.checkWebLoginQrcode(qrcodeKey: self.qrcodeKey) { checkResult in
                        if checkResult.code == 0 {
                            let setSu = loginService.setRefreshToken(checkResult.refresh_token)
                            alertText = "保存登录数据" + setSu.string(trueStr: "成功", falseStr: "失败")
                            showingAlert = true
                            if setSu {
                                // TODO: 登录成功后操作
                            }
                        } else {
                            alertText = checkResult.message
                            showingAlert = true
                        }
                    } fail: { error in
                        alertText = error
                        showingAlert = true
                    }

                }) {
                    Text("我已经登录").font(.title)
                }
                .alert("Error", isPresented: $showingAlert) {
                    Button("OK", action: {})
                } message: {
                    Text(alertText)
                }
                .padding()
            }

        }.onAppear {
            if loginService.isLogin() {
                qrcodeText = "已登录"
            } else {
                self.loginService.getWebLoginQrcode { loginData in
                    print(loginData)
                    if loginData.qrcode_key.isNotEmpty {
                        qrcodeKey = loginData.qrcode_key
                        loginUrl = loginData.url
                        // self.qrCodeImage = QrcodeUtil().generateQRCode(from: loginData.url)
                        loginDataLoaded = true
                    } else {
                        loginDataLoaded = false
                        alertText = "空白二维码"
                        showingAlert = true
                    }
                } fail: { errorMsg in
                    loginDataLoaded = false
                    showingAlert = true
                    alertText = errorMsg
                }
                // self.getQrcodeData()
            }
        }.navigationTitle("哔哩哔哩登入")
    }
}

#Preview {
    BiliMainView()
}
