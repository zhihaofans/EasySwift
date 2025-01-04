//
//  ViewUtil.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/18.
//

import SwiftUI

public extension View {
    func showTextAlert(_ title: String, _ message: String, isPresented: Binding<Bool>,
                       onDismiss: (() -> Void)? = nil) -> some View
    {
        return alert(title, isPresented: isPresented) {
            Button("OK", action: {
                onDismiss?()
            })
        } message: {
            Text(message)
        }
    }

    func showInputAlert(_ title: String, _ message: String, isPresented: Binding<Bool>,
                        onDismiss: (() -> Void)? = nil) -> some View
    {
        return alert(title, isPresented: isPresented) {
            Button("OK", action: {
                onDismiss?()
            })
        } message: {
            Text(message)
        }
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No need to update the controller
    }
}
