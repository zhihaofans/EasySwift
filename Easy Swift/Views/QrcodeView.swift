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
import Vision
import VisionKit

struct QrcodeView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var qrcodeContent: String=""
    @State private var hasPermission=false
    @State private var isShowingScanner=false
    var body: some View {
        VStack {
            Form {
                Section(header: Text("输入二维码文本")) {
                    TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: self.$qrcodeContent, axis: .vertical).lineLimit(3)
                }
                #if os(iOS)
                Button(action: {
                    requestCameraThenPresentScanner()
                }) {
                    Label("扫一扫", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.04, green: 0.53, blue: 1.0), .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .blue.opacity(0.28), radius: 8, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
                .listRowBackground(Color.clear)
                #endif
                if self.qrcodeContent.isNotEmpty {
                    let qrImage=QrcodeUtil().generateQRCode(from: EncodeUtil().urlDecode(self.qrcodeContent), scale: 5.0)
                    if qrImage == nil {
                        Text("请安装APP")

                    } else {
                        // [UPDATED macOS] 跨平台显示二维码图片
                        #if os(iOS)
                        Image(uiImage: qrImage!)
                            .interpolation(.none) // 保持二维码边缘锐利
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 20)
                            .frame(width: 240, height: 240)
                        #elseif os(macOS)
                        Image(nsImage: qrImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 20)
                        #endif
                        Button(action: {
                            ClipboardUtil().setString(qrcodeContent)

                        }) {
                            Label("复制文字", systemImage: "arrow.right.page.on.clipboard")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.04, green: 0.53, blue: 1.0), .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .blue.opacity(0.28), radius: 8, y: 4)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .listRowBackground(Color.clear)
                        Button(action: {
                            ShareUtil().shareImage(img: qrImage!)
                        }) {
                            Label("分享二维码", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.04, green: 0.53, blue: 1.0), .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .blue.opacity(0.28), radius: 8, y: 4)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .listRowBackground(Color.clear)
                    }
                }
            }
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

    #if os(iOS)
    private func requestCameraThenPresentScanner() {
        Task {
            let status=await currentCameraAuthorizationStatus()

            switch status {
            case .authorized:
                await MainActor.run {
                    guard DataScannerViewController.isSupported,
                          DataScannerViewController.isAvailable
                    else {
                        alertTitle="扫码不可用"
                        alertText="当前设备不支持系统扫码，或相机暂时不可用。"
                        showingAlert=true
                        return
                    }
                    isShowingScanner=true
                }

            case .notDetermined:
                let granted=await requestAccess()
                await MainActor.run {
                    hasPermission=granted
                    if granted {
                        requestCameraThenPresentScanner()
                    } else {
                        alertTitle="获取相机权限失败"
                        alertText="请在系统设置中允许相机访问。"
                        showingAlert=true
                    }
                }

            case .denied, .restricted:
                await MainActor.run {
                    hasPermission=false
                    alertTitle="相机权限不可用"
                    alertText="请在系统设置中允许相机访问。"
                    showingAlert=true
                }

            @unknown default:
                break
            }
        }
    }
    #endif

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

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
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
            print("启动扫码失败：\(error.localizedDescription)")
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
