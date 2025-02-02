//
//  NoteItemModel.swift
//  Easy Swift
//
//  Created by zzh on 2024/8/25.
//

import Foundation
import SwiftData

@Model
class TodoItemDataModel {
    var id: UUID
    var title: String
    var desc: String
    var url: String
    var create_time: Int
    var finish_time: Int
    var notification_time: Int
    var group_id: String
    var tags: [String]
    init(id: UUID = UUID(), text: String, create_time: Int, update_time: Int) {
        self.id = id
        self.text = text
        self.create_time = create_time
        self.finish_time = finish_time
        self.notification_time = notification_time
        self.group_id = group_id
        self.tags = tags
    }
}
