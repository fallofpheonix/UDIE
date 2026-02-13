//
//  BottomSheet.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

struct BottomSheet<Content: View, ActiveSheet>: View {

    enum SheetPosition {
        case collapsed
        case expanded
    }

    @Binding var activeSheet: ActiveSheet?

    @State private var position: SheetPosition
    @GestureState private var dragOffset: CGFloat = 0

    let content: Content

    init(
        activeSheet: Binding<ActiveSheet?>,
        initialPosition: SheetPosition = .collapsed,
        @ViewBuilder content: () -> Content
    ) {
        self._activeSheet = activeSheet
        self._position = State(initialValue: initialPosition)
        self.content = content()
    }

    var body: some View {

        GeometryReader { geometry in

            let collapsedHeight = geometry.size.height * 0.3
            let expandedHeight = geometry.size.height * 0.7

            let currentHeight =
                position == .collapsed
                ? collapsedHeight
                : expandedHeight

            VStack {

                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.gray)
                    .padding(8)

                content
                    .padding()
            }
            .frame(
                width: geometry.size.width,
                height: currentHeight
            )
            .background(.regularMaterial)
            .cornerRadius(20)
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height - currentHeight / 2 + dragOffset
            )
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in

                        let threshold: CGFloat = 100

                        if value.translation.height > threshold {
                            activeSheet = nil
                            return
                        }

                        if value.translation.height < -threshold {
                            position = .expanded
                        } else {
                            position = .collapsed
                        }
                    }
            )
            .animation(.easeInOut, value: position)
        }
    }
}
