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
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        Text("调用系统分享")
                    }
                    .showShareTextView(textToShare, isPresented: $isShareSheetPresented)
                    NavigationLink("昨天", destination: DateTextView())
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

struct DateTextView: View {
    @State private var selectedDate = Date()
    @State private var resultText = "不是昨天"
    var body: some View {
        DatePicker("请选择日期", selection: $selectedDate, displayedComponents: [.date])
            .datePickerStyle(WheelDatePickerStyle()) // 使用轮盘样式
            .padding().onChange(of: selectedDate) { _, _ in
                if isYesterday(nowDate: Date(), date: selectedDate) {
                    resultText = "昨天"
                } else {
                    resultText = "不是昨天"
                }
            }

        Text("你选择的日期是: \(selectedDate, formatter: dateFormatter)")
            .padding()

        Text(resultText)
            .padding()
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    func isYesterday(nowDate: Date, date: Date) -> Bool {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: nowDate) {
            return false
        }
        let startOfDay1 = calendar.startOfDay(for: nowDate)
        let startOfDay2 = calendar.startOfDay(for: date)
        // 如果 date1 是 date2 的前一天
        let result = calendar.isDate(startOfDay1, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: startOfDay2)!)
        print(nowDate)
        print(date)
        print(result)
        return result
    }
}

// #Preview {
//    UITestView()
// }
