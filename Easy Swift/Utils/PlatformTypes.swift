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
