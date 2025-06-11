// Made by Lumaa

import SwiftUI

extension View {
    @ViewBuilder
    func conditionalSheet(isPresented: Binding<Bool>, condition: Bool = true, content: @escaping () -> some View) -> some View {
        if condition {
            self
                .sheet(isPresented: isPresented, content: content)
        } else {
            self
        }
    }
}
