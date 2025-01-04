//
//  UITestView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/3.
//

import SwiftUI
import SwiftUtils

struct UITestView: View {
    @State private var isShareSheetPresented = false
    @State private var textToShare = "这是我要分享的一段文本！"
    var body: some View {
        VStack {
            NavigationView {
                List {
                    NavigationLink("二维码", destination: QrcodeView())
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        Text("调用系统分享")
                    }
                    .sheet(isPresented: $isShareSheetPresented) {
                        ShareActivityView(activityItems: [textToShare])
                    }
                }
            }
        }
        .setNavigationTitle(AppUtil().getAppName())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)) {
                    Image(systemName: "person")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
        }
    }
}

// #Preview {
//    UITestView()
// }
