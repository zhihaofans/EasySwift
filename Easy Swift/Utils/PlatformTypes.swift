//
//  PlatformTypes.swift
//  Easy Swift
//
//  Created by zzh on 2025/10/12.
//

#if os(iOS)
import UIKit

public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformView = UIView
#elseif os(macOS)
import AppKit

public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformView = NSView
#endif

extension PlatformImage {
    /// 从 CGImage 构造（ImageIO 出的缩略图已经是转正后的像素，方向标记置为 up）
    static func from(cgImage: CGImage) -> PlatformImage {
        #if os(macOS)
        PlatformImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        PlatformImage(cgImage: cgImage, scale: 1, orientation: .up)
        #endif
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension Image {
    /// 跨平台构造（PlatformImage = UIImage / NSImage）。
    /// 放在这里而不是某个页面里：平台差异统一收口在本文件。
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
#endif
