//
//  CalculatorView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/14.
//

import SwiftUI

struct CalculatorView: View {
    private let calculatorType=CalculatorType()
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var nowCalculatorType: String=""
    var body: some View {
        VStack {
            Form {
                Menu("类型:\(nowCalculatorType)") {
                    Button("纺织品", action: { nowCalculatorType=calculatorType.TEXTILE })
                }
                Section(header: Text("输入二维码文本")) {
                    TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: $alertText)
                    Button(action: {}) {
                        Text("计算")
                    }
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

class CalculatorType {
    let TEXTILE="纺织品" // 纺织品
}

#Preview {
    CalculatorView()
}
