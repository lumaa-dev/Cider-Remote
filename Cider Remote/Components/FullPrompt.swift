// Made by Lumaa

import SwiftUI

struct FullPrompt: View {
    let prompt: Prompt
    let dismissAction: () -> Void

    init(_ prompt: Prompt, dismissAction: @escaping () -> Void) {
        self.prompt = prompt
        self.dismissAction = dismissAction
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            new // sheet
        } else {
            old // middle
        }
    }

    @available(iOS 26.0, *)
    var new: some View {
        prompt.view {
            dismissAction()
        }
    }

    var old: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    prompt.view {
                        dismissAction()
                    }
                    .padding(24)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)
                )
        }
        .transition(.opacity)
    }
}
