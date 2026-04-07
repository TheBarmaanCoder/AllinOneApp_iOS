import SwiftUI

struct SwipeToDelete: ViewModifier {
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false
    @State private var rowHeight: CGFloat = 0
    @State private var isDeleting = false

    private let deleteWidth: CGFloat = 80
    private let threshold: CGFloat = 60

    func body(content: Content) -> some View {
        if isDeleting {
            Color.clear.frame(height: 0)
        } else {
            ZStack(alignment: .trailing) {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(0, -offset))
                        .overlay {
                            if -offset > 30 {
                                Button {
                                    performDelete()
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                }

                content
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: RowHeightKey.self, value: geo.size.height)
                        }
                    )
                    .offset(x: offset)
            }
            .frame(height: isDeleting ? 0 : nil)
            .clipped()
            .onPreferenceChange(RowHeightKey.self) { rowHeight = $0 }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let drag = value.translation.width
                        if drag < 0 {
                            offset = drag
                        } else if showDelete {
                            offset = max(-deleteWidth, -deleteWidth + drag)
                        }
                    }
                    .onEnded { value in
                        let drag = value.translation.width
                        if drag < -200 {
                            performDelete()
                        } else if drag < -threshold {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -deleteWidth
                                showDelete = true
                            }
                        } else {
                            resetSwipe()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    if showDelete { resetSwipe() }
                }
            )
        }
    }

    private func resetSwipe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 0
            showDelete = false
        }
    }

    private func performDelete() {
        withAnimation(.easeOut(duration: 0.25)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.2)) {
                isDeleting = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDelete()
            }
        }
    }
}

private struct RowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(onDelete: onDelete))
    }
}
