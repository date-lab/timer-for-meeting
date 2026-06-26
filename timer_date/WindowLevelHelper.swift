//
//  WindowLevelHelper.swift
//  timer_date
//
//  Created by 野口祥生 on 2025/05/23.
//

import Foundation
import AppKit

/// アプリのメインウィンドウを「他アプリのネイティブ全画面の上にも常駐させる」状態に保つ。
///
/// 通常の `.regular` アプリ（Dock にアイコンが出る普通のアプリ）のウィンドウは、
/// ウィンドウレベルをどれだけ上げても他アプリのネイティブ全画面の上には回り込めない。
/// アプリを `.accessory`（Dock 非表示の常駐型）にすることで、全画面の上に表示できる。
@MainActor
final class FloatingWindowManager {
    static let shared = FloatingWindowManager()
    private var timer: Timer?
    private var didInitialOrderFront = false
    var isCompact = false

    private init() {}

    func start() {
        // Dock アイコンを消す代わりに、他アプリの全画面の上にも表示できるようにする
        NSApp.setActivationPolicy(.accessory)

        apply()
        guard timer == nil else { return }
        // SwiftUI による設定の上書きに負けないよう、毎秒再適用して維持する
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                FloatingWindowManager.shared.apply()
            }
        }
    }

    private func apply() {
        let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        for window in NSApp.windows {
            // 全画面アプリの上に回り込めるよう高いレベルにする
            window.level = .screenSaver
            // 全 Space に常駐し、全画面アプリ（専用 Space）にも一緒に表示する
            window.collectionBehavior = behavior
            // タイトルバーだけでなく背景をドラッグしても移動できるようにする
            window.isMovableByWindowBackground = true

            window.isOpaque = false

            if isCompact {
                window.backgroundColor = .clear
                window.styleMask.remove(.titled)
                window.hasShadow = false
                if let contentView = window.contentView {
                    for subview in contentView.subviews where subview is NSVisualEffectView {
                        subview.isHidden = true
                    }
                }
            } else {
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.3)
                if !window.styleMask.contains(.titled) {
                    window.styleMask.insert(.titled)
                }
                window.hasShadow = true
                if let contentView = window.contentView {
                    for subview in contentView.subviews where subview is NSVisualEffectView {
                        subview.isHidden = false
                    }
                }
            }
        }

        // .accessory だと起動時に自動で前面に来ないことがあるため、初回だけ前面に出す
        if !didInitialOrderFront, !NSApp.windows.isEmpty {
            for window in NSApp.windows {
                window.orderFrontRegardless()
            }
            didInitialOrderFront = true
        }
    }
}

/// アプリのメインウィンドウを常に前面・全 Space に保つ。
@MainActor
func makeWindowFloating() {
    FloatingWindowManager.shared.start()
}

@MainActor
func setWindowCompact(_ compact: Bool) {
    FloatingWindowManager.shared.isCompact = compact
}
