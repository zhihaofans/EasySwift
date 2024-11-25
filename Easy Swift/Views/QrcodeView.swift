//
//  QrcodeView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import SwiftUtils

struct QrcodeView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var qrcodeContent: String=""
    var body: some View {
        VStack {
            Form {
                Section(header: Text("输入二维码文本")) {
                    TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: $qrcodeContent)
                    Button(action: {}) {
                        Text("申请相机权限")
                    }
                }
                if qrcodeContent.isNotEmpty {
                    let qrImage=self.generateQRCode(from: EncodeUtil().urlDecode(qrcodeContent))
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
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                alertTitle=""
                alertText=""
                showingAlert=false
            })
        } message: {
            Text(alertText)
        }
        .setNavigationTitle("二维码")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    
                }) {
                    Text("相机权限")
                }
            }
        }
    }

    private func generateQRCode(from string: String, scale: CGFloat=5.0) -> UIImage? {
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
}

#Preview {
    QrcodeView()
}
