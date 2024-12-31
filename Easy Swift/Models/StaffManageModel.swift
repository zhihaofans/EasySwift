//
//  StaffManageModel.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/31.
//

import Foundation
import SwiftData

@Model
class StaffManageItemModel {
    var id: UUID
    var name: String // 姓名
    var text: String
    var create_time: Int
    var update_time: Int
    var salary: Int // 工资
    var separated: Bool // 已离职
    var lastLeaveTime: Int // 最后请假时间
    var leaveList: [StaffLeaveItem] // 请假记录
    var salaryAdvance: [StaffSalaryAdvanceItem] // 工资预支记录
    init(id: UUID, name: String, text: String, create_time: Int, update_time: Int, salary: Int, separated: Bool, lastLeaveTime: Int, leaveList: [StaffLeaveItem], salaryAdvance: [StaffSalaryAdvanceItem]) {
        self.id = id
        self.name = name
        self.text = text
        self.create_time = create_time
        self.update_time = update_time
        self.salary = salary
        self.separated = separated
        self.lastLeaveTime = lastLeaveTime
        self.leaveList = leaveList
        self.salaryAdvance = salaryAdvance
    }
}

// 请假记录
struct StaffLeaveItem {
    var time: Int // 请假时间
    var reason: String // 请假原因
    var days: Int // 请假天数
    var isMonthLeave: Bool // 是否月假
    var notes: String // 备注
    var create_time: Int // 创建时间
}

// 工资预支记录
struct StaffSalaryAdvanceItem {
    var time: Int // 时间
    var amount: Int // 金额
    var notes: String // 备注
}
