//
//  AlertView.swift
//  Easy Swift
//
//  Created by zzh on 2025/2/3.
//

import SwiftUI

struct InputAlertView: View {
    let title: String
    let placeholder: String
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var callback: (String) -> Void // 回调闭包

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            TextField(placeholder, text: $inputText)
                .textFieldStyle(.roundedBorder)
                .padding()

            HStack {
                Button("取消") {
                    isPresented=false
                }
                .foregroundColor(.red)
                .padding(.horizontal)

                Button("确定") {
                    isPresented=false
                    callback(inputText)
                }
                .foregroundColor(.blue)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}
