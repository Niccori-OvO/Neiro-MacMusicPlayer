//
//  Animations.swift
//  Neiro
//
//  通用动画 helper：hover 抬升、按钮按压反馈、页面切换 transition。
//

import SwiftUI

// MARK: - Hover lift

public extension View {
    /// hover 时轻微抬升 + 阴影加深，适合卡片。
    func hoverLift(scale: CGFloat = 1.025, lift: CGFloat = 2) -> some View {
        modifier(HoverLift(scale: scale, lift: lift))
    }

    /// 按下时缩小一点点，更有按钮感。
    func pressDown(scale: CGFloat = 0.96) -> some View {
        modifier(PressDown(scale: scale))
    }
}

private struct HoverLift: ViewModifier {
    let scale: CGFloat
    let lift: CGFloat
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hover ? scale : 1.0)
            .offset(y: hover ? -lift : 0)
            .shadow(color: .black.opacity(hover ? 0.20 : 0.0),
                    radius: hover ? 10 : 0,
                    y: hover ? 6 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: hover)
            .onHover { hover = $0 }
    }
}

private struct PressDown: ViewModifier {
    let scale: CGFloat
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true } }
                    .onEnded { _ in pressed = false }
            )
    }
}

// MARK: - Page transition

public extension AnyTransition {
    /// 主内容区切换页面用的过渡：稍偏右 + 渐隐
    static var neiroPage: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8, y: 0)),
            removal: .opacity.combined(with: .offset(x: -8, y: 0))
        )
    }
}

// MARK: - SidebarRow hover

struct HoverableRow<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var hover = false

    var body: some View {
        content()
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hover ? Color.primary.opacity(0.06) : .clear)
            )
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}
