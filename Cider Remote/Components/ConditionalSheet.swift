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

    @ViewBuilder
    func conditionalSheet<Item: Identifiable>(item: Binding<Item?>, condition: Bool = true, content: @escaping (Item) -> some View) -> some View {
        if condition {
            self
                .sheet(item: item, content: content)
        } else {
            self
        }
    }
}
