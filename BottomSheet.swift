import SwiftUI

struct BottomSheet<Content: View>: View {
    @Binding private var activeSheet: Any?
    @ViewBuilder private let content: Content
    
    @GestureState private var dragOffset = CGSize.zero
    
    private let dragThreshold: CGFloat = 100
    
    init(activeSheet: Binding<Any?>, @ViewBuilder content: () -> Content) {
        self._activeSheet = activeSheet
        self.content = content()
    }
    
    init(activeSheet: Binding<MapView.ActiveSheet?>, @ViewBuilder content: () -> Content) {
        self._activeSheet = Binding<Any?>(
            get: { activeSheet.wrappedValue },
            set: { newValue in
                if let castValue = newValue as? MapView.ActiveSheet? {
                    activeSheet.wrappedValue = castValue
                } else {
                    activeSheet.wrappedValue = nil
                }
            }
        )
        self.content = content()
    }
    
    var body: some View {
        if activeSheet != nil {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    // Background blur and tap to dismiss
                    VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                activeSheet = nil
                            }
                        }
                    
                    sheetView(proxy: proxy)
                        .transition(.move(edge: .bottom))
                        .animation(.interactiveSpring(), value: activeSheet != nil)
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    @ViewBuilder
    private func sheetView(proxy: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            handleBar
            content
                .padding(.bottom, proxy.safeAreaInsets.bottom)
            
            dismissButton
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(radius: 10)
        )
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > dragThreshold {
                        withAnimation {
                            activeSheet = nil
                        }
                    }
                }
        )
    }
    
    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .frame(width: 40, height: 5)
            .foregroundColor(Color.secondary)
            .padding(.top, 8)
    }
    
    private var dismissButton: some View {
        Button(action: {
            withAnimation {
                activeSheet = nil
            }
        }) {
            Text("Dismiss")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
    }
}

// UIKit wrapper for blur effect
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// Dummy MapView and ActiveSheet for compilation
// Remove or replace with actual MapView in real project
struct MapView {
    enum ActiveSheet {
        case example
    }
}
