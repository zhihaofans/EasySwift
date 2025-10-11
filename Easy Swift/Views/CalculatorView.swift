//
//  CalculatorView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/14.
//

import SwiftUI

struct CalculatorView: View {
    @State private var showingAlert = false
    @State private var alertTitle: String = "未知错误"
    @State private var alertText: String = "未知错误"
    var body: some View {
        VStack {
            List {
                NavigationLink("人体BMI计算", destination: BMICalculatorView())
            }
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
        .setNavigationTitle("计算器")
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) { Text("设置") }
                }
            #else
                ToolbarItem(placement: .automatic) {
                    Button(action: {}) { Text("设置") }
                }
            #endif
        }
    }
}

private struct BMICalculatorView: View {
    @State private var inputHeight: String = "1.8" // 身高，米
    @State private var inputWeight: String = "80.0" // 体重，公斤
    @State private var isShowAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var result: String = ""
    var body: some View {
        VStack {
            List {
                // 文本框小数键盘在 iOS 有效；macOS 自动回退
                TextField("身高(m)", text: self.$inputHeight)
                    .setDecimalType()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .disableAutocorrection(true)

                TextField("体重(kg)", text: self.$inputWeight)
                    .setDecimalType()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .disableAutocorrection(true)

                Button("计算") {
                    calculateBMI()
                }
            }
        }
        .setNavigationTitle("BMI计算")
        .showTextAlert(alertTitle, alertMessage, isPresented: $isShowAlert)
    }

    private func calculateBMI() {
        guard inputHeight.isNotEmpty, inputWeight.isNotEmpty else { return }
        let height = Double(inputHeight) ?? 0
        let weight = Double(inputWeight) ?? 0
        guard height > 0, weight > 0 else {
            alertTitle = "错误"
            alertMessage = "身高、体重不是正确的数字"
            isShowAlert = true
            return
        }
        let bmiRaw = weight / (height * height)
        let bmi = (bmiRaw * 10).rounded() / 10.0
        let desc: String
        if bmi < 18.5 {
            desc = "过轻"
        } else if bmi >= 30 {
            desc = "肥胖"
        } else if bmi >= 25 {
            desc = "超重"
        } else {
            desc = "正常"
        }
        result = "BMI: \(String(format: "%.1f", bmi))（\(desc)）"
    }
}

public extension TextField {
    /// iOS：使用小数键盘；macOS：无操作
    func setNumberType() -> some View {
        #if os(iOS)
            return keyboardType(.decimalPad)
        #else
            return self
        #endif
    }
}

// #Preview {
//    CalculatorView()
// }
