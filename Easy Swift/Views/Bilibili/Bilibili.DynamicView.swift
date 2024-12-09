//
//  Bilibili.DynamicView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/7.
//

import Alamofire
import SwiftUI
import SwiftUtils

struct BiliDynamicView: View {
    @State private var isError=false
    @State private var loaded=false
    @State private var errorStr=""
    @State private var dynamicList: [BiliDynamicListItem]=[]
    private let dynamicType=BiliDynamicType()
    var body: some View {
        ScrollView {
            if loaded {
                if isError {
                    Text("Error").font(.largeTitle)
                    Text(errorStr)
                } else {
                    LazyVStack {
                        Section(header: Text("共\(dynamicList.count)个动态").foregroundColor(.blue), footer: Text("下面的内容还不能给你看").foregroundColor(.red)) {
                            ForEach(dynamicList, id: \.id_str) { item in
                                //                            switch item.type {
                                //                            case DynamicType().WORD:
                                //                                DynamicItemTextView(itemData: item)
                                //                            default:
                                //                                DynamicItemOldView(itemData: item)
                                //                            }
                                switch item.type {
//                                    case dynamicType.VIDEO:
//                                        NavigationLink {
//                                            BiliVideoInfoView(bvid: item.modules.module_dynamic.major?.archive?.bvid ?? "")
//                                        } label: {
//                                            DynamicItemImageView(itemData: item)
//                                                .contentShape(Rectangle()) // 加这行才实现可点击
//                                        }
                                default:
                                    DynamicItemImageView(itemData: item)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Loading...")
                ProgressView()
            }
        }
        .navigationBarTitle("动态", displayMode: .inline)
        .onAppear {
            // TODO: 加载动态数据
            Task {
                BiliDynamicService().getDynamicList { result in
                    DispatchQueue.main.async {
                        if result.data == nil || result.data!.items.isEmpty {
                            isError=true
                            errorStr="空白结果列表"
                        } else {
                            dynamicList=result.data!.items
                            isError=false
                        }
                        loaded=true
                    }
                } fail: { err in
                    DispatchQueue.main.async {
                        isError=true
                        loaded=true
                        errorStr=err
                    }
                }
            }
        }
    }
}

struct DynamicItemImageView: View {
    var itemData: BiliDynamicListItem
    private let defaultImg="https://i0.hdslb.com/bfs/activity-plat/static/20220518/49ddaeaba3a23f61a6d2695de40d45f0/2nqyzFm9He.jpeg"
    private var imageUrl: String?
    private var dynamicText: String
    @State private var hasImage=false
    @State private var showingAlert=false
    @State private var alertTitle=""
    @State private var alertText=""
    private let UDUtil=UserDefaultUtil()
    @AppStorage("open_web_in_app") private var openWebInApp: Bool=false
    private let dynamicType=BiliDynamicType()
    private let dynamicService=BiliDynamicService()
    private let appService=BiliAppService()
    init(itemData: BiliDynamicListItem) {
        self.itemData=itemData
        self.dynamicText=itemData.getTitle()
        @AppStorage("bili_dynamic_image_mode") var isDynamicShowImage=true
//        debugPrint(itemData.modules.module_dynamic.major?.type)
        // debugPrint(contentJson)
        if isDynamicShowImage {
            switch itemData.type {
            case dynamicType.DRAW:
                self.hasImage=true
                self.imageUrl=itemData.modules.module_dynamic.major?.draw?.items[0].src
            case dynamicType.VIDEO:
                self.hasImage=true
                self.imageUrl=itemData.modules.module_dynamic.major?.archive?.cover
            case dynamicType.ARTICLE:
                self.hasImage=true
                self.imageUrl=itemData.modules.module_dynamic.major?.article?.covers[0]
            case dynamicType.LIVE_RCMD:
                let contentJson=itemData.modules.module_dynamic.major?.live_rcmd?.content
                if contentJson != nil {
                    let data=try? JSONDecoder().decode(BiliDynamicListItemModuleDynamicMajorLiveRcmdContent.self, from: contentJson!.data(using: .utf8)!)
//                    debugPrint(data)
                    if data != nil {
                        self.dynamicText=data!.getTitle() ?? dynamicText
                        self.imageUrl=data!.getCover()
                        self.hasImage=true
                    } else {
                        self.hasImage=false
                    }
//                    debugPrint(imageUrl)
//                    debugPrint(hasImage)
                }
            default:
                self.hasImage=false
                self.imageUrl=nil
            }
        } else {
            self.hasImage=false
            self.imageUrl=nil
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                HStack {
                    AsyncImage(url: URL(string: itemData.modules.module_author.face)) { image in
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
                    Text(itemData.modules.module_author.name)
                        .font(.title2)
                    Spacer()
                    Text(itemData.modules.module_author.pub_time + " " + itemData.modules.module_author.pub_action)
                        .padding(.trailing, 10) // 在右侧添加 10 点的内间距
                }
                .frame(maxHeight: .infinity) // 设置对齐方式
                .onClick {
                    let webUrl=appService.checkLink(itemData.modules.module_author.jump_url)
                    appService.openUrl(appUrl: webUrl, webUrl: webUrl)
                }
//                .contentShape(Rectangle()) // 加这行才实现可点击
//                .onTapGesture {
//                    AppService().openAppUrl(self.checkLink(itemData.modules.module_author.jump_url))
//                }
                Text(dynamicText)
                    .lineLimit(2)
                    .padding(.horizontal, 20) // 设置水平方向的内间距
                if imageUrl != nil && imageUrl!.isNotEmpty {
                    let drawList: [BiliDynamicListItemModuleDynamicMajorDrawItem]=itemData.modules.module_dynamic.major?.draw?.items ?? []
                    if itemData.type == dynamicType.DRAW && drawList.isNotEmpty {
                        NavigationLink {
                            BiliPreviewView(type: "image", dataList: drawList.map { $0.src })
                        } label: {
                            BiliDynamicImageItemView(imageUrl: imageUrl!)
                        }
                    } else if itemData.type == dynamicType.VIDEO {
                        NavigationLink {
                            BiliVideoInfoView(bvid: itemData.modules.module_dynamic.major?.archive?.bvid ?? "")
                        } label: {
                            BiliDynamicImageItemView(imageUrl: imageUrl!)
                        }
                    } else {
                        BiliDynamicImageItemView(imageUrl: imageUrl!)
                    }
                }
                Spacer()
            }
        }
        .background(Color(.secondarySystemBackground)) // 设置背景色以便观察效果
//        .frame(height: 150) // 将 VStack 的固定高度设置为100
        .frame(minHeight: 100)
        // TODO: 重写动态点击事件
//        .contentShape(Rectangle()) // 加这行才实现可点击
//        .onTapGesture {
//            // TODO: onClick
//            print(itemData)
//            switch itemData.type {
//            case DynamicType().VIDEO:
//                let urlStr=self.checkLink(itemData.modules.module_dynamic.major?.archive?.jump_url)
//                if openWebInApp {
//                    AppService().openAppUrl(urlStr)
//                } else {
//                    Task {
//                        DispatchQueue.main.async {
//                            if urlStr.isNotEmpty {
//                                if let url=URL(string: urlStr) {
//                                    DispatchQueue.main.async {
//                                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            case DynamicType().ARTICLE:
//                let urlStr=self.checkLink(itemData.modules.module_dynamic.major?.article?.jump_url)
//                if openWebInApp {
//                    AppService().openAppUrl(urlStr)
//                } else {
//                    Task {
//                        DispatchQueue.main.async {
//                            if urlStr.isNotEmpty {
//                                if let url=URL(string: urlStr) {
//                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                                }
//                            }
//                        }
//                    }
//                }
//            case DynamicType().LIVE_RCMD:
        ////                print(itemData.modules.module_dynamic.major?.live_rcmd)
//                alertTitle="@" + itemData.modules.module_author.name + " 开播了"
//                alertText=itemData.modules.module_dynamic.major?.live_rcmd?.content ?? "[??]"
//                showingAlert=true
//            default:
//                print(itemData.type)
//                alertTitle="@" + itemData.modules.module_author.name
//                alertText=itemData.modules.module_dynamic.getTitle() ?? "[没有标题]"
//                showingAlert=true
//            }
//        }
        .alert(alertTitle, isPresented: $showingAlert) {
            TextField("Placeholder", text: $alertText)
            Button("OK", action: {
                showingAlert=false
            })
        } message: {
            Text(alertText)
        }
    }

    private func checkLink(_ url: String?) -> String {
        var urlStr=url ?? ""
        if urlStr.starts(with: "//") {
            urlStr="https:" + urlStr
        }
        if urlStr.starts(with: "http://") {
            urlStr=urlStr.replace(of: "http://", with: "https://")
        }
        return urlStr
    }
}

struct BiliDynamicImageItemView: View {
    private let defaultImg="https://i0.hdslb.com/bfs/activity-plat/static/20220518/49ddaeaba3a23f61a6d2695de40d45f0/2nqyzFm9He.jpeg"
    var imageUrl: String
    var body: some View {
        AsyncImage(url: URL(string: imageUrl.replace(of: "http://", with: "https://"))) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFit() // 图片将等比缩放以适应框架
                .padding(.horizontal, 20) // 设置水平方向的内间距
        } placeholder: {
            ProgressView()
        }
        //                    .padding(.leading, 20) // 在左侧添加 10 点的内间距
    }
}

struct BiliDynamicDetailView: View {
    private var dynamicData: BiliDynamicListItem
    init(_ itemData: BiliDynamicListItem) {
        self.dynamicData=itemData
    }

    var body: some View {
        Text("正在打开动态")
        ProgressView()
    }
}
