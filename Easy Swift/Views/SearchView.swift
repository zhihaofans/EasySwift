//
//  SearchView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/12.
//

import SwiftUI
import SwiftUtils

struct SearchView: View {
    @State private var isShareSheetPresented = false
    @State private var SearchKey = "这是我要分享的一段文本！"
    var body: some View {
        VStack {
            NavigationView {
                List {
                    TextField("搜点什么", text: $SearchKey)
                    Button(action: {
                        // TODO: Search
                    }) {
                        Text("Go to Search")
                    }
                }
            }
        }
        .setNavigationTitle("Search")
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
//    SearchView()
// }
