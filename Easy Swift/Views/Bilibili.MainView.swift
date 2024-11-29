//
//  BiliMainView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/26.
//

import SwiftUI

struct BiliMainView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var qrcodeContent: String=""
    @State private var isLogin=false
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
                Text("未登录").font(.largeTitle)
            }
        }
        .onAppear {
            
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                self.alertTitle=""
                self.alertText=""
                self.showingAlert=false
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

#Preview {
    BiliMainView()
}
