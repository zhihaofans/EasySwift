//
//  ContentView.swift
//  Easy Swift
//
//  应用根视图：目前只承载 MainView，单独保留是为了给 #Preview 留入口。
//
//  Created by zzh on 2024/11/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
}
