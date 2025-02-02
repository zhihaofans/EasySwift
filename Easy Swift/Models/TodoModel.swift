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
    var create_time: Date
    var finish_time: Date?
    var notification_time: Date?
    var group_id: String
    var tags: [String]
    init(id: UUID, title: String, desc: String, url: String, create_time: Date, finish_time: Date?, notification_time: Date?, group_id: String, tags: [String]) {
        self.id = id
        self.title = title
        self.desc = desc
        self.url = url
        self.create_time = create_time
        self.finish_time = finish_time
        self.notification_time = notification_time
        self.group_id = group_id
        self.tags = tags
    }
}
