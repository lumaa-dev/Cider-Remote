// Made by Lumaa

import SwiftUI

struct ChangelogsView: View {
    private static let changelogs: [Changelog] = [.v300]
    @State private var selectedChangelog: Changelog? = nil

    var body: some View {
        list
            .sheet(item: $selectedChangelog) { log in
                log.view {
                    self.selectedChangelog = nil
                }
                .interactiveDismissDisabled()
            }
    }

    var list: some View {
        List {
            if let first = Self.changelogs.first {
                Button {
                    self.selectedChangelog = first
                } label: {
                    self.banner(changelog: first)
                }
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(Text("Changelogs"))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func banner(color: AnyGradient = Color.cider.gradient, changelog: Changelog) -> some View {
        VStack(spacing: 0) {
            Text(changelog.version)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, minHeight: 100)
                .font(
                    .system(size: CGFloat.getFontSize(UIFont.preferredFont(forTextStyle: .largeTitle)) + 25.0, weight: .black)
                    .width(.expanded)
                )
                .lineLimit(1)
                .background(color)
                .foregroundStyle(Color.white)

            Divider()

            HStack(spacing: 8) {
                Text("Remote \(changelog.version)")
                    .foregroundStyle(Color(uiColor: UIColor.label))

                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.secondary)
            }
            .font(.body)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10.0)
        }
    }
}

struct Changelog: Hashable, Identifiable {
    static var v300: Changelog {
        var temp = Changelog(version: "3.0.0", authors: ["Lumaa"])
        temp = temp
            .setChanges(additions: [
                "In-app changelogs"
            ], modifications: [
                "Queue and lyrics appear on the same page",
                "Search results now use the new listing system",
                "Changed play/pause button icon",
                "Time and volume bars grow thicker when dragging",
                "Current track is always displayed in big or small",
                "Darkened current track background for contrast",
                "Better background tasks for Live Activities",
                "Usage of current APIs rather than deprecated ones",
                "Prompts have been simplified",
                "Xcode project organization",
                "Fix: Tapping a search result now plays the right track",
                "Fix: Labels are now always white whatever color scheme in use",
                "Fix: Background tasks are now correctly scheduled and ran"
            ], removals: [
                "Queue track index used for developers",
                "The \"Album Art Size\" setting, defaulted to large"
            ])
        return temp
            .setNotes(headerNote: "Cider Remote 3.0.0 releases along with Cider 3.0.0, this Remote update greatly improves the UI.")
    }

    var id: String {
        "CiderRemote_v\(self.version.replacing(/\.+/, with: ""))"
    }
    let version: String
    let authors: [String]
    var additions: [String] = []
    var modifications: [String] = []
    var removals: [String] = []
    var header: String? = nil
    var footer: String? = nil

    init(version: String, authors: [String] = []) {
        self.version = version
        self.authors = authors
    }

    mutating func setChanges(additions: [String] = [], modifications: [String] = [], removals: [String] = []) -> Self {
        self.additions = additions
        self.modifications = modifications
        self.removals = removals
        return self
    }

    mutating func setNotes(headerNote: String? = nil, footerNote: String? = nil) -> Self {
        self.header = headerNote
        self.footer = footerNote
        return self
    }

    func view(dismiss: @escaping () -> Void) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                HStack {
                    Text("Remote \(self.version)")
                        .font(.title.bold())
                        .lineLimit(1)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(Color.cider)
                    }
                }
                .frame(maxWidth: .infinity)

                if let header {
                    Text(header)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 15.0)
                        .padding(.vertical, 10.0)
                        .background(Color(uiColor: UIColor.tertiarySystemBackground).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                }

                if !self.additions.isEmpty {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Text("Added:")
                            .font(.title2.bold())
                            .lineLimit(1)
                        
                        ForEach(self.additions, id: \.self) { added in
                            HStack(alignment: .top) {
                                Image(systemName: "plus.circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.green)

                                Text(added)
                                    .font(.callout)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                if !self.modifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Text("Changed:")
                            .font(.title2.bold())
                            .lineLimit(1)

                        ForEach(self.modifications, id: \.self) { modified in
                            HStack(alignment: .top) {
                                Image(systemName: "pencil.circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.yellow)

                                Text(modified)
                                    .font(.callout)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                if !self.removals.isEmpty {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Text("Removed:")
                            .font(.title2.bold())
                            .lineLimit(1)

                        ForEach(self.removals, id: \.self) { removed in
                            HStack(alignment: .top) {
                                Image(systemName: "minus.circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.red)

                                Text(removed)
                                    .font(.callout)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                if let footer {
                    Text(footer)
                        .font(.subheadline)
                        .padding(.horizontal, 15.0)
                        .padding(.vertical, 10.0)
                        .background(Color(uiColor: UIColor.tertiarySystemBackground).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
                }

                VStack(alignment: .leading, spacing: 8.0) {
                    Text("Contributors for \(self.version):")
                        .font(.title2.bold())
                        .lineLimit(1)

                    HStack {
                        ForEach(self.authors, id: \.self) { author in
                            Text(author)
                                .font(.callout.width(.expanded))
                                .padding(.horizontal, 10.0)
                                .padding(.vertical, 5.0)
                                .background(Color(uiColor: UIColor.tertiarySystemBackground).opacity(0.5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    ChangelogsView()
}
