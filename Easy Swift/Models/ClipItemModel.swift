//
//  NoteItemModel.swift
//  Easy Swift
//
//  Created by zzh on 2024/8/25.
//

import Foundation
import SwiftData

@Model
class ClipItemDataModel {
    var id: UUID
    var text: String
    var create_time: Int
    var update_time: Int
    init(id: UUID = UUID(), text: String, create_time: Int, update_time: Int) {
        self.id = id
        self.text = text
        self.create_time = create_time
        self.update_time = update_time
    }
}
