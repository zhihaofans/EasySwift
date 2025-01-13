//
//  CalculatorView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/14.
//

import SwiftUI

struct CalculatorView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    var body: some View {
        VStack {
            NavigationView {
                List {
                    NavigationLink("人体BMI计算", destination: BMICalculatorView())
                }
            }
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
        .setNavigationTitle("计算器")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Text("设置")
                }
            }
        }
    }
}

private struct BMICalculatorView: View {
    @State private var inputHeight: Float=180
    @State private var inputWeight: Float=80.0
    var body: some View {
        VStack {
            List {
                
            }
        }
    }
}

// #Preview {
//    CalculatorView()
// }
