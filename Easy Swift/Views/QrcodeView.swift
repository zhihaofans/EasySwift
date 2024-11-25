//
//  QrcodeView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import SwiftUtils

import AVFoundation

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
                        Image(uiImage: qrImage!)
                            .resizable() // 使图像可调整大小
                            .aspectRatio(contentMode: .fit) // 保持图片的比例适应视图大小
                            .padding(.horizontal, 20) // 水平方向内间距
//                            .resizable().frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 100)
                    }
                }
            }
        }
        .alert(self.alertTitle, isPresented: self.$showingAlert) {
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    CameraUtil().checkCameraPermissions {
                        self.hasPermission=true
                    } fail: { err in
                        self.hasPermission=false
                        self.alertTitle="获取相机权限失败"
                        self.alertText=err
                        self.showingAlert=false
                    }

                }) {
                    Text("相机权限")
                }
            }
        }
    }

    init() {
        @State var hasPer=self.hasPermission
        self.checkCameraPermissions(success: {
            hasPer=true
        }) { _ in
            hasPer=false
        }
    }

    private func generateQRCode(from string: String, scale: CGFloat=5.0)->UIImage? {
        let context=CIContext()
        let filter=CIFilter.qrCodeGenerator()
        let data=Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // 高纠错级别

        if let qrCodeImage=filter.outputImage {
            let transformedImage=qrCodeImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            if let qrCodeCGImage=context.createCGImage(transformedImage, from: transformedImage.extent) {
                return UIImage(cgImage: qrCodeCGImage)
            }
        }
        return nil
    }

    private func checkCameraPermissions(success: @escaping ()->Void, fail: @escaping (String)->Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                success()
            // 已经授权
            case .notDetermined:
                fail("未授权")
            case .denied:
                return // 用户拒绝授权
                    fail("用户拒绝授权")
            case .restricted:
                fail("系统限制")
                return // 系统限制
            @unknown default:
                fatalError()
        }
    }

    private func getCameraPermissions(success: @escaping ()->Void, fail: @escaping (String)->Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                // 用户拒绝授权
                fail("用户拒绝授权")
            } else {
                success()
            }
        }
    }
}

#Preview {
    QrcodeView()
}
