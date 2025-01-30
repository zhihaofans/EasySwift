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
        .alert(self.alertTitle, isPresented: self.$showingAlert) {
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
    @State private var inputHeight: String="1.8" // 身高，米
    @State private var inputWeight: String="80.0" // 体重，公斤
    @State private var isShowAlert: Bool=false
    @State private var alertTitle: String=""
    @State private var alertMessage: String=""
    var body: some View {
        VStack {
            List {
                TextField("身高", text: self.$inputHeight).setNumberType()
                TextField("体重", text: self.$inputWeight)
                Button(action: {
                    // TODO: Search
                    if self.inputHeight.isNotEmpty {
                        if self.isFloat(self.inputHeight), self.isFloat(self.inputWeight) {
                        } else {
                            self.alertTitle="错误"
                            self.alertMessage="身高、体重不是正确的数字"
                            self.isShowAlert=true
                        }
                    }
                }) {
                    Text("计算")
                }
            }
        }.showTextAlert(self.alertTitle, self.alertMessage, isPresented: self.$isShowAlert)
    }

    func isFloat(_ str: String) -> Bool {
        print(str)
        print(Float(str) != nil)
        return Float(str) != nil
    }
}

public extension TextField {
    func setNumberType() -> some View {
        return self.keyboardType(.decimalPad) // 设置为小数键盘
//            .padding()
//            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

// #Preview {
//    CalculatorView()
// }
