// Made by Lumaa

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.dismiss) private var dismiss: DismissAction

    @EnvironmentObject var colorScheme: ColorSchemeManager
    @EnvironmentObject var deviceListViewModel: DeviceListViewModel

    @AppStorage("buttonSize") private var buttonSize: ElementSize = .medium
    @AppStorage("albumArtSize") private var albumArtSize: ElementSize = .large
    @AppStorage("autoRefresh") private var autoRefresh: Bool = true
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0
    @AppStorage("useAdaptiveColors") private var useAdaptiveColors: Bool = true
    @AppStorage("deviceDetails") private var deviceDetails: Bool = false
    @AppStorage("alertLiveActivity") private var alertLiveActivity: Bool = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Feedback")) {
                    Button {
                        if let url = URL(string: "https://github.com/ciderapp/Cider-Remote/issues/new") {
                            openURL(url)
                        }
                    } label: {
                        Label("Report a Bug", systemImage: "ladybug.fill")
                    }

                    Button {
                        if let url = URL(string: "https://apps.apple.com/app/id6670149407?action=write-review") {
                            openURL(url)
                        }
                    } label: {
                        Label("Review Cider Remote", systemImage: "star.fill")
                    }
                }

                Section(header: Text("Appearance")) {
                    Toggle(isOn: $useAdaptiveColors) {
                        Label("Use Dynamic Colors", systemImage: "paintpalette.fill")
                    }
                    .foregroundStyle(Color(uiColor: UIColor.label))

                    Picker(selection: $buttonSize) {
                        ForEach(ElementSize.allCases) { size in
                            Text(size.rawValue.capitalized)
                                .id(size)
                        }
                    } label: {
                        Label("Button Size", systemImage: "button.horizontal.top.press.fill")
                    }
                    .foregroundStyle(Color(uiColor: UIColor.label))
                    .pickerStyle(.menu)
                }

                Section(header: Text("Advanced")) {
                    Toggle("Device Information", isOn: $deviceDetails)

                    Toggle(isOn: $alertLiveActivity) {
                        HStack(spacing: 8.0) {
                            unstablePill

                            Text("Playback Notification")
                        }
                    }
                }

                Section(header: Text("Devices")) {
//                    Button("Reset All Devices", role: .destructive, action: resetAllDevices)
                    Toggle("Automatically Refresh", isOn: $autoRefresh)

                    VStack(alignment: .leading) {
                        HStack(alignment: .center) {
                            Text("Refresh Interval")
                                .foregroundStyle(autoRefresh ? Color(uiColor: UIColor.label) : Color.gray)
                            Spacer()
                            Text("\(Int(refreshInterval)) seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $refreshInterval, in: 5...60, step: 5) {
                            Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                        }
                        .disabled(!autoRefresh)
                        .onChange(of: refreshInterval) { _ in
                            let impact = UIImpactFeedbackGenerator(style: .light) //MARK: API is deprecated
                            impact.impactOccurred()
                        }
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    
                    NavigationLink {
                        ChangelogsView()
                    } label: {
                        Text("Changelogs")
                    }
                }

                Section {
                    Text("© Cider Collective 2024-2025")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        ContributorsView()
                    } label: {
                        Text("Made with ❤️ by contributors")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: "https://apple.co/4k6ISFv") {
                        ShareLink("Share Cider Remote", item: url)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var unstablePill: some View {
        Text("Unstable")
            .font(.caption)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 3.0)
            .background(Color.blue)
            .clipShape(Capsule())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ColorSchemeManager())
            .environmentObject(DeviceListViewModel())
    }
}

enum ElementSize: String, Hashable, CaseIterable, Identifiable {
    case small, medium, large
    var id: Self { self }

    var dimension: CGFloat {
        switch self {
            case .small: return 40
            case .medium: return 60  // This was 50 before, now it's 60 to match the original size
            case .large: return 80   // Increased to take up more space
        }
    }

    var fontSize: CGFloat {
        switch self {
            case .small: return 16
            case .medium: return 24  // Increased from 20 to 24
            case .large: return 32   // Increased from 24 to 32
        }
    }

    var padding: CGFloat {
        switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 20   // Increased from 16 to 20
        }
    }
}
