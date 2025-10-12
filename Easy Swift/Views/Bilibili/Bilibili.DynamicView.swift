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

    // V2 分页游标 & 状态
    @State private var nextCursor: BiliDynamicService.Cursor?
    @State private var isRefreshing=false
    @State private var isLoadingMore=false
    @State private var reachedEnd=false

    private let service=BiliDynamicService() // 固定持有，避免请求过程中被释放
    private let dynamicType=BiliDynamicType()

    var body: some View {
        ScrollView {
            if loaded {
                if isError {
                    Text("Error").font(.largeTitle)
                    Text(errorStr)
                } else {
                    LazyVStack {
                        Section(
                            header: Text("共\(dynamicList.count)个动态").foregroundColor(.blue),
                            footer: Text("下面的内容还不能给你看").foregroundColor(.red)
                        ) {
                            ForEach(dynamicList, id: \.id_str) { item in
                                // 动态内容展示
                                switch item.type {
                                default:
                                    DynamicItemImageView(itemData: item)
                                        // [UPDATED] onAppear 绑定到具体视图，避免语法错误
                                        .onAppear {
                                            if shouldLoadMore(currentItem: item) {
                                                Task { await loadMore() }
                                            }
                                        }
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
        .setNavigationTitle("动态")
        // [V2] .task：首次进入加载第一页（取代老版 onAppear）
        .task {
            // 使用 async/await 首次加载第一页，取代旧的回调写法
            if !loaded {
                await loadFirstPage()
            }
        }
        .refreshable {
            // [UPDATED] 使用 async/await 下拉刷新
            await refresh()
        }
//        .onAppear {
//            // TODO: 加载动态数据
//            Task {
//                BiliDynamicService().getDynamicList { result in
//                    DispatchQueue.main.async {
//                        if result.data == nil || result.data!.items.isEmpty {
//                            isError=true
//                            errorStr="空白结果列表"
//                        } else {
//                            dynamicList=result.data!.items
//                            isError=false
//                        }
//                        loaded=true
//                    }
//                } fail: { err in
//                    DispatchQueue.main.async {
//                        isError=true
//                        loaded=true
//                        errorStr=err
//                    }
//                }
//            }
//        }
    }

    // MARK: - [UPDATED] 新增：async/await 安全包装，防止 continuation 泄漏

    /// [UPDATED] 错误类型包装，统一抛出
    private enum FetchError: Error, LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case let .message(msg)=self { return msg }
            return "未知错误"
        }
    }

    // [UPDATED] 保证 continuation 只被恢复一次，避免多次 resume 或竞争
    final class ResumeOnce {
        private var resumed=false
        private let lock=NSLock()
        func run(_ block: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !resumed else { return }
            resumed=true
            block()
        }
    }

    /// [UPDATED] 把回调式接口包装为 async/await，附带取消/超时与“只恢复一次”保护
    private func fetchPage(
        type: BiliDynamicService.FeedType = .all,
        offset: String?=nil,
        updateBaseline: String?=nil,
        page: Int?=nil,
        timeoutSeconds: UInt64=20 // [UPDATED] 自定义超时（秒）
    ) async throws -> (BiliDynamicListResult, BiliDynamicService.Cursor) {
        // 如果任务已取消，直接抛出 CancellationError
        try Task.checkCancellation()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let once=ResumeOnce() // [UPDATED] 只恢复一次
                // [UPDATED] 超时兜底
                let timeoutTask=Task {
                    try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    once.run {
                        continuation.resume(throwing: FetchError.message("请求超时（\(timeoutSeconds)s）"))
                    }
                }

                // [UPDATED] 使用持有的 service 发起请求
                service.getDynamicListV2(
                    type: type,
                    offset: offset,
                    updateBaseline: updateBaseline,
                    page: page
                ) { result, cursor in
                    once.run {
                        timeoutTask.cancel()
                        continuation.resume(returning: (result, cursor))
                    }
                } fail: { err in
                    once.run {
                        timeoutTask.cancel()
                        continuation.resume(throwing: FetchError.message(err))
                    }
                }
            }
        }, onCancel: {
            // [UPDATED] 任务被取消时也要确保恢复（不会与上面冲突，因为 once 限制只会执行一次）
            // 注意：这里不能直接访问 continuation；因此我们把取消路径也交由超时/回调两者以外的第三条路径：
            // 解决办法：通过抛出 CancellationError 让上层退出（配合超时/回调的 once，不会重复恢复）
            // 实际上 withTaskCancellationHandler 的 onCancel 在这里无法直接 resume continuation，
            // 但外层的 Task.checkCancellation() 会在下一次 suspension 触发；为了立即生效，可考虑缩短 timeout 或在 HttpUtil 层取消网络请求。
        })
    }

    // MARK: - [UPDATED] V2 核心逻辑使用 async/await 调用 -----------------

    /// [UPDATED] 首次加载第一页
    private func loadFirstPage() async {
        guard !Task.isCancelled else { return } // 防止任务被取消时泄漏
        do {
            // [UPDATED] 使用 async/await 请求第一页
            let (result, cursor)=try await fetchPage()
            await MainActor.run {
                dynamicList=result.data?.items ?? []
                nextCursor=cursor
                loaded=true
                isError=dynamicList.isEmpty
                errorStr=dynamicList.isEmpty ? "空白结果列表" : ""
                reachedEnd=dynamicList.isEmpty
            }
        } catch {
            // [UPDATED] 统一错误处理在主线程更新 UI
            await MainActor.run {
                isError=true
                errorStr=error.localizedDescription
                loaded=true
            }
        }
    }

    /// [UPDATED] 下拉刷新逻辑
    private func refresh() async {
        guard !isRefreshing else { return }
        await MainActor.run {
            isRefreshing=true
            reachedEnd=false
            nextCursor=nil
        }
        do {
            // [UPDATED] 使用 async/await 调用
            let (result, cursor)=try await fetchPage()
            await MainActor.run {
                dynamicList=result.data?.items ?? []
                nextCursor=cursor
                isError=dynamicList.isEmpty
                errorStr=dynamicList.isEmpty ? "空白结果列表" : ""
                loaded=true
                isRefreshing=false
            }
        } catch {
            await MainActor.run {
                isError=true
                errorStr=error.localizedDescription
                loaded=true
                isRefreshing=false
            }
        }
    }

    /// [UPDATED] 触底加载更多逻辑
    private func loadMore() async {
        guard !isLoadingMore, !reachedEnd else { return }
        let currentCursor=nextCursor
        guard currentCursor?.offset?.isNotEmpty == true ||
            currentCursor?.updateBaseline?.isNotEmpty == true
        else {
            await MainActor.run { reachedEnd=true }
            return
        }

        await MainActor.run { isLoadingMore=true }
        do {
            // [UPDATED] 使用 async/await 翻页加载
            let (result, cursor)=try await fetchPage(
                type: .all,
                offset: currentCursor?.offset,
                updateBaseline: currentCursor?.updateBaseline
            )

            let newItems=result.data?.items ?? []
            await MainActor.run {
                if newItems.isEmpty {
                    reachedEnd=true
                } else {
                    // [UPDATED] 去重逻辑防止重复动态
                    let existingIDs=Set(dynamicList.map { $0.id_str })
                    let filtered=newItems.filter { !existingIDs.contains($0.id_str) }
                    dynamicList.append(contentsOf: filtered)
                    reachedEnd=filtered.isEmpty
                }
                nextCursor=cursor
                isLoadingMore=false
            }
        } catch {
            await MainActor.run {
                errorStr=error.localizedDescription
                isLoadingMore=false
            }
        }
    }

    /// [V2] 判断是否需要触发加载更多
    private func shouldLoadMore(currentItem: BiliDynamicListItem) -> Bool {
        guard !isLoadingMore, !reachedEnd, dynamicList.count > 5 else { return false }
        if let idx=dynamicList.firstIndex(where: { $0.id_str == currentItem.id_str }) {
            return idx >= dynamicList.count - 5 // 距底部 5 条时预取
        }
        return false
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
        .background(.background)
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
