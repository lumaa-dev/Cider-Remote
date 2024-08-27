//
//  ContentView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var colorScheme = ColorSchemeManager()
    @State private var showingSettings = false
    @StateObject private var deviceListViewModel = DeviceListViewModel()

    var body: some View {
        NavigationStack {
            DevicesView(showingSettings: $showingSettings)
                .environmentObject(deviceListViewModel)
        }
        .accentColor(colorScheme.primaryColor)
        .environmentObject(colorScheme)
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingSettings: $showingSettings)
        }
    }
}

struct DevicesView: View {
    @EnvironmentObject private var viewModel: DeviceListViewModel
    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            CiderHeaderView()

            List {
                ForEach(viewModel.devices) { device in
                    NavigationLink(value: device) {
                        DeviceRowView(device: device)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteDevice(device: device)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode, viewModel: viewModel)
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.startActivityChecking()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationDestination(for: Device.self) { device in
            LazyView(MusicPlayerView(device: device))
        }
        .onAppear {
            viewModel.startActivityChecking()
        }
        .onDisappear {
            viewModel.stopActivityChecking()
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct CiderHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
            
            Text("Cider Devices")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
    }
}

struct StatusIndicator: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.red)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: isActive ? Color.green.opacity(0.5) : Color.red.opacity(0.5), radius: 2)
    }
}

struct DeviceIconView: View {
    let device: Device

    var body: some View {
        Image(uiImage: deviceImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var deviceImage: UIImage {
        switch device.platform {
        case "win32": return UIImage(named: "Windows") ?? UIImage(systemName: "desktopcomputer")!
        case "darwin": return UIImage(named: "macOS") ?? UIImage(systemName: "desktopcomputer")!
        case "linux": return UIImage(named: "Linux") ?? UIImage(systemName: "desktopcomputer")!
        default: return UIImage(systemName: "desktopcomputer")!
        }
    }
}

struct DeviceRowView: View {
    @ObservedObject var device: Device

    var body: some View {
        HStack(spacing: 12) {
            DeviceIconView(device: device)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(device.version) | \(device.platform)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("Host: \(device.host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            StatusIndicator(isActive: device.isActive)
        }
        .padding(.vertical, 8)
    }
}

struct DeviceInfoView: View {
    let device: Device
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(device.friendlyName)
                .font(.headline)
                .foregroundColor(.white)
            Text("\(device.version) | \(device.platform)")
                .font(.subheadline)
            Text("Host: \(device.host)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundColor(.red)
                .offset(x: 60)
        }
        .padding()
    }
}

struct RefreshingView: View {
    let isRefreshing: Bool
    
    var body: some View {
        if isRefreshing {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Refreshing...")
            }
            .padding()
        }
    }
}

struct AddDeviceView: View {
    @Binding var isShowingScanner: Bool
    @Binding var scannedCode: String?
    @ObservedObject var viewModel: DeviceListViewModel

    var body: some View {
        Button(action: {
            isShowingScanner = true
        }) {
            Label("Add New Cider Device", systemImage: "plus.circle")
        }
        .sheet(isPresented: $isShowingScanner) {
            QRScannerView(scannedCode: $scannedCode)
        }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                viewModel.fetchDevices(from: code)
                isShowingScanner = false
            }
        }
    }
}

enum Size: String, CaseIterable, Identifiable {
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

struct SettingsView: View {
    @Binding var showingSettings: Bool
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @AppStorage("buttonSize") private var buttonSize: Size = .medium
    @AppStorage("albumArtSize") private var albumArtSize: Size = .large
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0
    @AppStorage("useAdaptiveColors") private var useAdaptiveColors: Bool = true
    @EnvironmentObject var deviceListViewModel: DeviceListViewModel

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("TestFlight")) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Thank you for testing!")
                            .font(.headline)
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Feedback")) {
                    Button(action: reportBug) {
                        Label("Report a Bug", systemImage: "ladybug.fill")
                    }
                }

                Section(header: Text("Appearance")) {
                    Toggle("Use Dynamic Colors", isOn: $useAdaptiveColors)
                    
                    VStack {
                        HStack {
                            Image(systemName: "button.horizontal.top.press.fill")
                            Text("Button Size")
                        }
                        Picker("Button Size", selection: $buttonSize) {
                            ForEach(Size.allCases) { size in
                                Text(size.rawValue.capitalized).tag(size)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text("Album Art Size")
                        }
                        Picker("Album Art Size", selection: $albumArtSize) {
                            ForEach(Size.allCases) { size in
                                Text(size.rawValue.capitalized).tag(size)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Section(header: Text("Devices")) {
                    Button("Reset All Devices", role: .destructive, action: resetAllDevices)
                    
                    VStack(alignment: .leading) {
                        Text("Refresh Interval")
                        Slider(value: $refreshInterval, in: 5...60, step: 5) {
                            Text("Refresh Interval: \(Int(refreshInterval)) seconds")
                        }
                        Text("\(Int(refreshInterval)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("© Cider Collective 2024")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("Made with ❤️ by cryptofyre")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.headline)
                }
            }
        }
    }

    private func reportBug() {
        if let url = URL(string: "https://github.com/ciderapp/Cider-Remote/issues/new") {
            UIApplication.shared.open(url)
        }
    }
    
    private func resetAllDevices() {
       //TODO
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showingSettings: .constant(true))
            .environmentObject(ColorSchemeManager())
            .environmentObject(DeviceListViewModel())
    }
}
#Preview {
    ContentView()
}
