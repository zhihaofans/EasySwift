//
//  QrcodeView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI
import SwiftUtils

struct QrcodeView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var qrcodeContent: String=""
    @State private var hasPermission=false
    var body: some View {
        VStack {
            Form {
                Section(header: Text("输入二维码文本")) {
                    TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: self.$qrcodeContent)
                    Button(action: {}) {
                        Text("扫一扫(\(self.hasPermission ? "已授权" : "未授权"))")
                    }
                }
                if self.qrcodeContent.isNotEmpty {
                    let qrImage=self.generateQRCode(from: EncodeUtil().urlDecode(self.qrcodeContent))
                    if qrImage == nil {
                        Text("请安装APP")

                    } else {
                        // [UPDATED macOS] 跨平台显示二维码图片
                        #if os(iOS)
                        Image(uiImage: qrImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 20)
                        #elseif os(macOS)
                        Image(nsImage: qrImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 20)
                        #endif
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                self.alertTitle=""
                self.alertText=""
                self.showingAlert=false
            })
        } message: {
            Text(self.alertText)
        }
        .setNavigationTitle("二维码")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("相机权限") { requestCameraPermissions() }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button("相机权限") { requestCameraPermissions() }
            }
            #endif
        }
        .task {
            // [首次进入时检查权限（不弹系统框）
            hasPermission=await currentCameraAuthorizationStatus() == .authorized
        }
    }

    // MARK: - 生命周期初始化（修复版）

    // 删除了原先 init() 里对 @State 的错误使用。
    // SwiftUI View 中不用在 init 里读/写 @State；改为在 .task / .onAppear 中做。

    // MARK: - 二维码生成（跨平台）

    private func generateQRCode(from string: String, scale: CGFloat=5.0) -> PlatformImage? {
        let context=CIContext()
        let filter=CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // 高纠错级别

        guard let output=filter.outputImage else { return nil }
        let transformed=output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage=context.createCGImage(transformed, from: transformed.extent) else { return nil }

        // [UPDATED macOS] 返回跨平台图片
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        let size=NSSize(width: transformed.extent.width, height: transformed.extent.height)
        let image=NSImage(cgImage: cgImage, size: size)
        return image
        #endif
    }

    // 说明：
    //  - macOS 10.14+/iOS 7+ 可用 AVFoundation 权限 API
    //  - Info.plist 需包含 NSCameraUsageDescription（iOS/macOS 都需要）

    private func requestCameraPermissions() {
        Task {
            let status=await currentCameraAuthorizationStatus()
            switch status {
            case .authorized:
                await MainActor.run { hasPermission=true }

            case .notDetermined:
                // 首次请求：会弹系统权限弹窗
                let granted=await requestAccess()
                await MainActor.run {
                    hasPermission=granted
                    if !granted {
                        alertTitle="获取相机权限失败"
                        alertText="用户拒绝授权"
                        showingAlert=true
                    }
                }

            case .denied, .restricted:
                await MainActor.run {
                    hasPermission=false
                    alertTitle="相机权限不可用"
                    alertText=(status == .denied) ? "用户拒绝授权" : "系统限制"
                    showingAlert=true
                }

            @unknown default:
                await MainActor.run {
                    hasPermission=false
                    alertTitle="未知权限状态"
                    alertText="请检查系统设置"
                    showingAlert=true
                }
            }
        }
    }

    // 当前授权状态（不会触发系统弹窗）
    private func currentCameraAuthorizationStatus() async -> AVAuthorizationStatus {
        // iOS / macOS 通用
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    // 发起授权请求（会触发系统弹窗）
    private func requestAccess() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                cont.resume(returning: granted)
            }
        }
    }
}

#Preview {
    QrcodeView()
}
