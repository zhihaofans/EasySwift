//
//  PreviewView.swift
//  Bili-Swift
//
//  Created by zzh on 2024/10/24.
//

import SwiftUI

struct BiliPreviewView: View {
    @State private var imageList: [String]
    init(type: String, dataList: [String]) {
        self.imageList = dataList
    }

    var body: some View {
        ScrollView {
            if imageList.isEmpty {
                Text("Error").font(.largeTitle)
                Text("空白图片列表")
            } else {
                LazyVStack {
                    Section(header: Text("共\(imageList.count)个图片").foregroundColor(.blue), footer: Text("完毕desu~").foregroundColor(.red)) {
                        ForEach(imageList, id: \.self) { url in
                            //                            switch item.type {
                            //                            case DynamicType().WORD:
                            //                                DynamicItemTextView(itemData: item)
                            //                            default:
                            //                                DynamicItemOldView(itemData: item)
                            //                            }
                            AsyncImage(url: URL(string: BiliAppService().checkLink(url))) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .scaledToFit() // 图片将等比缩放以适应框架
                                    .padding(.horizontal, 20) // 设置水平方向的内间距
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                }
            }
        }
        .setNavigationTitle("预览图片")
    }
}
