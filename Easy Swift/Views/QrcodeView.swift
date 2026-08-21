//
//  QrcodeView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//
import AVFoundation
import PhotosUI
import SwiftUI
import SwiftUtils
import Vision
import VisionKit

struct QrcodeView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var qrcodeContent: String=""
    @State private var isShowingScanner=false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isDecoding=false
    var body: some View {
        VStack(spacing: 16) {
            // 输入区：OS 26 玻璃材质，加大尺寸
            TextField("输入二维码文本", text: self.$qrcodeContent, axis: .vertical)
                .lineLimit(3)
                .font(.title3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)
            #if os(iOS)
            HStack {
                Spacer()
                Button(action: {
                    requestCameraThenPresentScanner()
                }) {
                    Label {
                        Text("扫一扫")
                    } icon: {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundStyle(.tint)
                            .padding(5)
                            .background(Circle().fill(.white))
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                Spacer()
            }
            #endif
            if isDecoding {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在解析二维码...")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if self.qrcodeContent.isNotEmpty {
                let qrImage=QrcodeUtil().generateQRCode(from: EncodeUtil().urlDecode(self.qrcodeContent), scale: 5.0)
                if qrImage == nil {
                    Text("请安装APP")

                } else {
                    // 二维码与操作按钮移出 Form：去掉分割线与行背景，整体水平居中
                    HStack {
                        Spacer()
                        #if os(iOS)
                        Image(uiImage: qrImage!)
                            .interpolation(.none) // 保持二维码边缘锐利
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 240, height: 240)
                        #elseif os(macOS)
                        Image(nsImage: qrImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 240, height: 240)
                        #endif
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    HStack(spacing: 16) {
                        Spacer()
                        Button(action: {
                            ClipboardUtil().setString(qrcodeContent)
                        }) {
                            Label {
                                Text("复制文字")
                            } icon: {
                                Image(systemName: "arrow.right.page.on.clipboard")
                                    .foregroundStyle(.tint)
                                    .padding(5)
                                    .background(Circle().fill(.white))
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        Button(action: {
                            ShareUtil().shareImage(img: qrImage!)
                        }) {
                            Label {
                                Text("分享二维码")
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.tint)
                                    .padding(5)
                                    .background(Circle().fill(.white))
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        #if os(iOS)
        .sheet(isPresented: $isShowingScanner) {
            QRScannerView { value in
                qrcodeContent=value
                isShowingScanner=false
            }
            .ignoresSafeArea()
        }
        #endif
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
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .labelStyle(.titleAndIcon)
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .labelStyle(.titleAndIcon)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    pasteImageFromClipboard()
                } label: {
                    Label("粘贴图片", systemImage: "doc.on.clipboard")
                        .labelStyle(.titleAndIcon)
                }
            }
            #endif
        }
        .onChange(of: selectedPhoto) { _, newValue in
            decodeQR(from: newValue)
        }
    }

    // 说明：
    //  - macOS 10.14+/iOS 7+ 可用 AVFoundation 权限 API
    //  - Info.plist 需包含 NSCameraUsageDescription（iOS/macOS 都需要）

    // 从相册图片解析二维码（非二维码图片会提示）
    private func decodeQR(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            isDecoding=true
        }
        Task {
            guard let data=try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    isDecoding=false
                    showAlert(title: "读取失败", text: "无法加载所选图片")
                }
                return
            }
            await decodeImageData(data)
        }
    }

    #if os(macOS)
    // 从剪贴板粘贴图片并自动解析二维码
    private func pasteImageFromClipboard() {
        let pasteboard=NSPasteboard.general
        var data=pasteboard.data(forType: .tiff)
        if data == nil { data=pasteboard.data(forType: .png) }
        if data == nil {
            // 剪贴板中是图片文件
            if let fileURL=NSURL(from: pasteboard) as URL? {
                data=try? Data(contentsOf: fileURL)
            }
        }
        guard let data else {
            showAlert(title: "剪贴板无图片", text: "请先复制一张包含二维码的图片")
            return
        }
        Task { @MainActor in
            isDecoding=true
        }
        Task {
            await decodeImageData(data)
        }
    }
    #endif

    // 解析图片数据中的二维码（相册与剪贴板共用）
    private func decodeImageData(_ data: Data) async {
        #if os(macOS)
        guard let image=NSImage(data: data) else {
            await MainActor.run {
                isDecoding=false
                showAlert(title: "读取失败", text: "无法加载所选图片")
            }
            return
        }
        var rect=CGRect(origin: .zero, size: image.size)
        guard let cgImage=image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            await MainActor.run {
                isDecoding=false
                showAlert(title: "读取失败", text: "无法加载所选图片")
            }
            return
        }
        #else
        guard let cgImage=UIImage(data: data)?.cgImage else {
            await MainActor.run {
                isDecoding=false
                showAlert(title: "读取失败", text: "无法加载所选图片")
            }
            return
        }
        #endif

        let request=VNDetectBarcodesRequest()
        request.symbologies=[.qr]
        var payload: String?
        var decodeError: String?
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            payload=request.results?.first?.payloadStringValue
        } catch {
            decodeError=error.localizedDescription
        }
        await MainActor.run {
            isDecoding=false
            if let payload {
                qrcodeContent=payload
                selectedPhoto=nil
            } else if let decodeError {
                showAlert(title: "解析失败", text: decodeError)
            } else {
                showAlert(title: "未识别到二维码", text: "所选图片中没有检测到二维码，请选择包含二维码的图片")
            }
        }
    }

    @MainActor
    private func showAlert(title: String, text: String) {
        alertTitle=title
        alertText=text
        showingAlert=true
    }

    #if os(iOS)
    private func requestCameraThenPresentScanner() {
        CameraUtil().checkCameraPermissions(success: {
            Task { @MainActor in
                guard DataScannerViewController.isSupported,
                      DataScannerViewController.isAvailable
                else {
                    self.alertTitle="扫码不可用"
                    self.alertText="当前设备不支持系统扫码，或相机暂时不可用。"
                    self.showingAlert=true
                    return
                }
                self.isShowingScanner=true
            }
        }, fail: { message in
            Task { @MainActor in
                self.alertTitle="相机权限不可用"
                self.alertText=message
                self.showingAlert=true
            }
        })
    }
    #endif
}

#if os(iOS)
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerHostController {
        QRScannerHostController(onScan: onScan)
    }

    func updateUIViewController(
        _ uiViewController: QRScannerHostController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ uiViewController: QRScannerHostController,
        coordinator: ()
    ) {
        uiViewController.stopScanning()
    }
}

@MainActor
final class QRScannerHostController: UIViewController {
    private let scanner=DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.qr])],
        qualityLevel: .balanced,
        recognizesMultipleItems: false,
        isHighFrameRateTrackingEnabled: true,
        isPinchToZoomEnabled: true,
        isGuidanceEnabled: true,
        isHighlightingEnabled: true
    )

    private let onScan: (String) -> Void
    private var recognitionTask: Task<Void, Never>?
    private var hasReturnedResult=false

    init(onScan: @escaping (String) -> Void) {
        self.onScan=onScan
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(scanner.view)

        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func startScanning() {
        guard !scanner.isScanning, !hasReturnedResult else { return }

        do {
            try scanner.startScanning()
        } catch {
            debugPrint("启动扫码失败：\(error.localizedDescription)")
            return
        }

        recognitionTask?.cancel()
        recognitionTask=Task { [weak self, weak scanner] in
            guard let self, let scanner else { return }

            for await items in scanner.recognizedItems {
                guard !self.hasReturnedResult else { return }

                for case let .barcode(code) in items {
                    guard let value=code.payloadStringValue else { continue }

                    self.hasReturnedResult=true
                    scanner.stopScanning()
                    self.onScan(value)
                    return
                }
            }
        }
    }

    func stopScanning() {
        recognitionTask?.cancel()
        recognitionTask=nil

        if scanner.isScanning {
            scanner.stopScanning()
        }
    }
}
#endif
#Preview {
    QrcodeView()
}
