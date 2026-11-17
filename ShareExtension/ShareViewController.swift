//
//  ShareViewController.swift
//  ShareExtension
//
//  在系统分享面板里接收**文本/链接**，写进 App Group 里的 inbox.json，然后自动关闭。
//
//  设计取舍：
//  - 不用模板的 SLComposeServiceViewController：它会展示一个编辑框 + "Post" 按钮，
//    对"收个链接"来说多一次点击；这里用极简 VC，进入就处理、处理完自己关掉。
//  - 不做分类：分类规则只在 InboxClassifier 一处（主 App 与扩展共用同一个文件），
//    扩展写入时就顺手把 kind 算好，收件箱列表直接显示。
//  - 不碰网络：分享动作必须是毫秒级的，任何联网都可能让系统把扩展杀掉。
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel=UILabel()
    private let spinner=UIActivityIndicatorView(style: .medium)
    private let openButton=UIButton(type: .system)
    private let doneButton=UIButton(type: .system)
    private var didFinish=false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        titleLabel.text="正在收进 Easy Swift…"
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines=0

        spinner.startAnimating()

        openButton.setTitle("打开 Easy Swift", for: .normal)
        openButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        openButton.addTarget(self, action: #selector(tapOpen), for: .touchUpInside)
        openButton.isHidden=true
        openButton.setContentHuggingPriority(.required, for: .horizontal)

        doneButton.setTitle("完成", for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        doneButton.addTarget(self, action: #selector(tapDone), for: .touchUpInside)
        doneButton.isHidden=true

        let buttons=UIStackView(arrangedSubviews: [openButton, doneButton])
        buttons.axis = .horizontal
        buttons.spacing=20
        buttons.alignment = .center

        let stack=UIStackView(arrangedSubviews: [spinner, titleLabel, buttons])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing=12
        stack.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await intake() }
    }

    // MARK: - 取内容

    private func intake() async {
        let text=await collectedText()
        var message="没有找到可收的文本或链接"
        if let text, !text.isEmpty {
            let fileURL=InboxFile.defaultFileURL()
            let item=InboxFile.append(rawText: text, source: .share, to: fileURL)
            if item != nil {
                message="已收进收件箱（\(InboxClassifier.classify(text).kind.title)）"
            } else {
                // 写失败要如实说：多半是 App Group 不可写（entitlement / 签名不对）
                message="写入收件箱失败，请检查 App Group 签名"
            }
        }
        spinner.stopAnimating()
        titleLabel.text=message
        openButton.isHidden=false
        doneButton.isHidden=false

        // 兜底：2.5 秒没点就自己关（比之前多 1 秒，给「打开 Easy Swift」留点击时间）
        try? await Task.sleep(for: .milliseconds(2500))
        finish()
    }

    // MARK: - 按钮

    @objc private func tapDone() {
        finish()
    }

    /// 打开宿主 App。
    ///
    /// 之前判定"做不到"是我实现错了，对照 OhMyFile 的实现后修正（2026-11-18）：
    ///   1. 必须**把 responder 强转成 `UIApplication`** 再调 `open(_:options:completionHandler:)`；
    ///      我原先用 `responds(to: "openURL:") + perform`，命中的可能不是 UIApplication，
    ///      看着执行了其实被忽略。
    ///   2. `completeRequest` 必须**延后 0.6 秒**，紧跟 open 会把这请求一起取消掉。
    ///   3. `extensionContext.open` 只作兜底（对 share extension 常返回 false）。
    @objc private func tapOpen() {
        var components=URLComponents()
        components.scheme="easyswift"
        components.host="inbox"
        guard let url=components.url else { finish(); return }

        if !openViaResponderChain(url) {
            extensionContext?.open(url, completionHandler: nil)
        }
        // 给系统时间处理打开请求，再结束扩展；否则唤起会被取消
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.finish()
        }
    }

    private func openViaResponderChain(_ url: URL) -> Bool {
        var responder: UIResponder?=self
        while let current=responder {
            if let application=current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return true
            }
            responder=current.next
        }
        return false
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish=true
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 从分享内容里优先取 URL，其次正文文本，最后标题。
    ///
    /// 顺序不能反：Safari 分享网页时正文可能为空、URL 才是我们想要的；
    /// 而小红书/抖音分享出来的是**一整段文案**，这时只有 plain-text 有值。
    private func collectedText() async -> String? {
        guard let items=extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        var urlString: String?
        var plainText: String?
        var titleText: String?

        for item in items {
            if titleText == nil, let title=item.attributedTitle?.string,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                titleText=title
            }
            if plainText == nil, let content=item.attributedContentText?.string,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                plainText=content
            }
            for attachment in item.attachments ?? [] {
                if urlString == nil,
                   let value=await load(attachment, as: .url), !value.isEmpty
                {
                    urlString=value
                }
                if plainText == nil,
                   let value=await load(attachment, as: .plainText), !value.isEmpty
                {
                    plainText=value
                }
            }
        }

        if let urlString, !urlString.isEmpty {
            // 有 URL 时把正文也带上：可能夹着话题/描述，收件箱里看得更清楚
            if let plainText, plainText != urlString, plainText.count < 500 {
                return "\(plainText)\n\(urlString)"
            }
            return urlString
        }
        return plainText ?? titleText
    }

    /// 用 iOS 27 的 `loadObject(ofClass:)` 取内容（`loadItem(forTypeIdentifier:)` 已废弃）。
    /// NSString / NSData / NSURL 都符合 `NSItemProviderReading`，取到后统一转成字符串。
    private func load(_ provider: NSItemProvider, as type: UTType) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }

        if type == .url, let url=await loadObject(provider, NSURL.self) {
            return (url as URL).absoluteString
        }
        if let text=await loadObject(provider, NSString.self) {
            return text as String
        }
        // NSData 不符合 NSItemProviderReading，走 dataRepresentation 兜底（老式 provider 会给 Data）
        if let data=await loadData(provider, as: type) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func loadData(_ provider: NSItemProvider, as type: UTType) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            _=provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func loadObject<T: NSItemProviderReading>(_ provider: NSItemProvider, _ type: T.Type) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            _=provider.loadObject(ofClass: type) { object, _ in
                continuation.resume(returning: object as? T)
            }
        }
    }
}
