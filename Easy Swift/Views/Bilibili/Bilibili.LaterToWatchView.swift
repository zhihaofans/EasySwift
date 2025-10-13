//
//  LaterToWatchView.swift
//  Bili-Swift
//
//  Created by zzh on 2024/8/1.
//

import SwiftUI

struct BiliLaterToWatchView: View {
    @State var isError=false
    @State var loaded=false
    @State var errorStr=""
    @State var later2watchList: [BiliLater2WatchItem]=[]
    var body: some View {
        ScrollView {
            if loaded {
                if isError {
                    Text(errorStr).font(.largeTitle)
                } else {
                    LazyVStack {
                        ForEach(later2watchList, id: \.bvid) { item in
                            NavigationLink {
                                BiliVideoInfoView(bvid: item.bvid)
                            } label: {
                                BiliLater2WatchItemView(itemData: item)
                            }
                        }
                    }
                }
            } else {
                Text("Loading...")
                ProgressView()
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "trash")
            }
            #else
            ToolbarItem(placement: .automatic) {
                Image(systemName: "trash")
            }
            #endif
        }
        .setNavigationTitle("稍后再看")
        .onAppear {
            // TODO: 加载历史数据
            Task {
                BiliHistoryService().getLaterToWatch { result in
                    DispatchQueue.main.async {
                        if result.data.list.isEmpty {
                            isError=true
                            errorStr="空白结果列表"
                        } else {
                            later2watchList=result.data.list
                            isError=false
                        }
                        loaded=true
                    }
                } fail: { err in
                    DispatchQueue.main.async {
                        isError=true
                        errorStr=err
                    }
                }
            }
        }
    }
}

struct BiliLater2WatchItemView: View {
    @AppStorage("open_web_in_app") private var openWebInApp: Bool=false
    var itemData: BiliLater2WatchItem
    var body: some View {
//        NavigationLink {
//            BiliVideoInfoView(id: workFolder.id)
//        } label: {
//            Label("Work Folder", systemImage: "folder")
//        }

        VStack(alignment: .leading) {
            HStack {
                AsyncImage(url: URL(string: itemData.pic.replace(of: "http://", with: "https://"))) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 150, height: 84)
                VStack {
                    Text(itemData.title) // .font()
                    Text("@" + itemData.owner.name)
                }
                // .frame(width: geometry.size.width)
                Spacer()
            }.frame(maxHeight: .infinity, alignment: .leading) // 设置对齐方式
        }
        .frame(height: 100) // 将 VStack 的固定高度设置为100
//        .contentShape(Rectangle()) // 加这行才实现可点击
//        .onTapGesture {
//            // TODO: onClick
//            print(itemData)
//            if openWebInApp {
//                let urlStr=itemData.uri
//                Task {
//                    DispatchQueue.main.async {
//                        if urlStr.isNotEmpty {
//                            if let url=URL(string: urlStr) {
//                                DispatchQueue.main.async {
//                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                                }
//                            }
//                        }
//                    }
//                }
//            } else {
//                let urlStr="https://www.bilibili.com/video/\(itemData.bvid)/"
//                Task {
//                    DispatchQueue.main.async {
//                        if urlStr.isNotEmpty {
//                            if let url=URL(string: urlStr) {
//                                DispatchQueue.main.async {
//                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
        ////            switch itemData.history.getType() {
        ////                // case "archive":
        ////
        ////                default:
        ////                    print(itemData.getCover())
        ////            }
//        }
    }
}

// #Preview {
//    LaterToWatchView()
// }
