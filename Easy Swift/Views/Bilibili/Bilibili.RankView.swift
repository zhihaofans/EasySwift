//
//  RankView.swift
//  Bili-Swift
//
//  Created by zzh on 2024/10/28.
//

import SwiftUI
import SwiftUtils

struct BiliRankView: View {
    @State var isError=false
    @State var loaded=false
    @State var errorStr=""
    @State var rankList: [BiliVideoInfoData]=[]
    @AppStorage("open_web_in_app") private var openWebInApp=false
    var body: some View {
        ScrollView {
            if self.loaded {
                if self.isError {
                    Text(self.errorStr).font(.largeTitle)
                } else {
                    LazyVStack {
                        ForEach(self.rankList, id: \.bvid) { item in
                            RankItemView(itemData: item)
                        }
                    }
                }
            } else {
                Text("Loading...")
                ProgressView()
            }
        }
        // TODO: toolbar
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Image(systemName: "trash")
//            }
//        }
        .navigationTitle("热门榜")
        .onAppear {
            // TODO: 加载热门榜
            Task {
                BiliRankService().getRankList { result in
                    DispatchQueue.main.async {
                        if result.code != 0 {
                            self.errorStr="code(\(result.code)):\(result.message)"
                            self.isError=true
                        } else if result.data == nil {
                            self.errorStr="result.data = nil"
                            self.isError=true
                        } else if result.data!.list.isEmpty {
                            self.errorStr="空白热门榜"
                            self.isError=true
                        } else {
                            self.rankList=result.data!.list
                            self.isError=false
                        }
                        self.loaded=true
                    }
                } fail: { err in
                    DispatchQueue.main.async {
                        self.errorStr=err
                        self.isError=true
                        self.loaded=true
                    }
                }
            }
        }
    }
}

struct RankItemView: View {
    private let itemData: BiliVideoInfoData
    @State private var showingAlert=false
    @State private var alertTitle=""
    @State private var alertText=""
    @AppStorage("open_web_in_app") private var openWebInApp=false
    @AppStorage("bili_dynamic_image_mode") var isDynamicShowImage=true
    private let appService=BiliAppService()
    init(itemData: BiliVideoInfoData) {
        self.itemData=itemData
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                HStack {
                    AsyncImage(url: URL(string: appService.checkLink(self.itemData.owner.face))) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaledToFit() // 图片将等比缩放以适应框架
                            .frame(width: 40, height: 40) // 设置视图框架的大小
                            .clipShape(Circle()) // 裁剪成圆形
                            .overlay(Circle().stroke(Color.gray, lineWidth: 4)) // 可选的白色边框
                    } placeholder: {
                        ProgressView()
                    }
                    .padding(.leading, 20) // 在左侧添加 10 点的内间距
                    //                    .frame(width: 40, height: 40)
                    Text(self.itemData.owner.name)
                        .font(.title2)
                    Spacer()
                    Text(DateUtil().timestampToTimeStr(self.itemData.pubdate, format: "MM-dd HH:mm"))
                        .padding(.trailing, 10) // 在右侧添加 10 点的内间距
                }
                .frame(maxHeight: .infinity) // 设置对齐方式
                .onClick {
                    let webUrl=appService.checkLink("https://space.bilibili.com/\(itemData.owner.mid)/")
                    appService.openUrl(appUrl: webUrl, webUrl: webUrl)
                }
                Text("[\(String(self.itemData.tname!))]")
                    .lineLimit(1)
                Text(self.itemData.title)
                    .lineLimit(3)

                NavigationLink {
                    BiliVideoInfoView(bvid: itemData.bvid)
                } label: {
                    AsyncImage(url: URL(string: appService.checkLink(self.itemData.pic))) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaledToFit() // 图片将等比缩放以适应框架
                            .padding(.horizontal, 20) // 设置水平方向的内间距
                    } placeholder: {
                        ProgressView()
                    }
                }
                Spacer()
            }
        }
        .background(Color(.secondarySystemBackground)) // 设置背景色以便观察效果
//        .frame(height: 150) // 将 VStack 的固定高度设置为100
        .frame(minHeight: 100)
//        .contentShape(Rectangle()) // 加这行才实现可点击
//        .onTapGesture {
//            // TODO: onClick
//            print(self.itemData)
//            if self.openWebInApp {
//                let urlStr="https://www.bilibili.com/video/\(itemData.bvid)"
//                AppService().openAppUrl(urlStr)
//            }
//        }
        .alert(alertTitle, isPresented: $showingAlert) {
            TextField("Placeholder", text: self.$alertText)
            Button("OK", action: {
                self.showingAlert=false
            })
        } message: {
            Text(self.alertText)
        }
    }
}

// #Preview {
//    HotView()
// }
