//
//  EmptyView.swift
//  Easy Swift
//
//  Created by zzh on 2025/2/1.
//

import SwiftUI

struct EmptyTextView: View {
    private let title: String
    private let text: String
    var body: some View {
        Spacer()
        Text(text).setNavigationTitle(title)
        Spacer()
    }

    init(title: String,text: String) {
        self.title = title
        self.text = text
    }
}

#Preview {
    EmptyView()
}
