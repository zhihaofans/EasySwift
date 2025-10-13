//
//  MacShareSupport.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/13.
//

#if os(macOS)
import AppKit
import SwiftUI

private struct MacSharingPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    var items: [Any]

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard isPresented else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
        DispatchQueue.main.async { self.isPresented = false }
    }
}

private struct MacShareTextModifier: ViewModifier {
    let text: String
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.background(
            MacSharingPicker(isPresented: $isPresented, items: [text])
                .frame(width: 0, height: 0)
        )
    }
}

public extension View {
    /// 与 iOS 的 `.showShareTextView` 对齐的 macOS 版本（全局仅此一处定义）
    func macShareTextView(_ text: String, isPresented: Binding<Bool>) -> some View {
        modifier(MacShareTextModifier(text: text, isPresented: isPresented))
    }

    /// 让 macOS 也支持同名 API：.showShareTextView(...)
    func showShareTextView(_ text: String, isPresented: Binding<Bool>) -> some View {
        modifier(MacShareTextModifier(text: text, isPresented: isPresented))
    }
}
#endif
