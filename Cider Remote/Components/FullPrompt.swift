// Made by Lumaa

import SwiftUI

struct FullPrompt: View {
    @Binding var isShowing: Bool
    let prompt: Prompt

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    prompt.view {
                        withAnimation(.spring) {
                            self.isShowing = false
                        }
                    }
                )
        }
        .transition(.opacity)
    }
}

/// A full-screen Cider prompt
struct Prompt {
    private let symbol: String
    private let title: String
    @ViewBuilder private let content: AnyView
    private let actionLabel: String
    private let action: () -> Void

    private var showCancel: Bool = true

    init(symbol: String, title: String, view: AnyView, actionLabel: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.content = view
        self.actionLabel = actionLabel
        self.action = action
    }

    mutating func cancellable(_ boolean: Bool = true) -> Prompt {
        var temp: Prompt = self
        temp.showCancel = boolean
        return temp
    }

    @ViewBuilder
    func view(dismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: self.symbol)
                    .font(.system(size: 50))
                    .foregroundStyle(Color.cider)

                Text(self.title)
                    .font(.title2.bold())
            }

            content

            HStack(spacing: 16) {
                if showCancel {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(self.actionLabel) {
                    self.action()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .frame(width: 320)
    }
}
