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
        ZStack {
            NavigationStack {
                DevicesView(showingSettings: $showingSettings)
            }
            .accentColor(colorScheme.primaryColor)
            
            if deviceListViewModel.showingNamePrompt {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        FriendlyNamePromptView()
                            .environmentObject(deviceListViewModel)
                            .environmentObject(colorScheme)
                    )
                    .transition(.opacity)
            }
            
            if deviceListViewModel.showingOldDeviceAlert {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay {
                        OldDeviceAlertView(isPresented: $deviceListViewModel.showingOldDeviceAlert)
                            .environmentObject(deviceListViewModel)
                            .environmentObject(colorScheme)
                    }
                    .transition(.opacity)
            }
        }
        .environmentObject(colorScheme)
        .environmentObject(deviceListViewModel)
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingSettings: $showingSettings)
        }
    }
}

struct DevicesView: View {
    @EnvironmentObject private var viewModel: DeviceListViewModel
    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var isShowingGuide = false
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            CiderHeaderView()

            List {
                ForEach(viewModel.devices) { device in
                    if device.isActive {
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
                    } else {
                        OfflineDeviceRowView(device: device) {
                            viewModel.deleteDevice(device: device)
                        }
                    }
                }

                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode, viewModel: viewModel)

                Button(action: {
                    isShowingGuide = true
                }) {
                    Label("Connection Guide", systemImage: "questionmark.circle")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                await viewModel.refreshDevices()
            }
            Label("This software is in BETA.", systemImage: "hammer.circle.fill")
                .foregroundColor(.gray)
                .accessibility(label: Text("Beta software"))
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
                    Task {
                        await viewModel.refreshDevices()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationDestination(for: Device.self) { device in
            LazyView(MusicPlayerView(device: device))
        }
        .sheet(isPresented: $isShowingGuide) {
            ConnectionGuideView()
        }
        .onAppear {
            viewModel.startActivityChecking()
        }
        .onDisappear {
            viewModel.stopActivityChecking()
        }
    }
}

struct OfflineDeviceRowView: View {
    let device: Device
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DeviceIconView(device: device)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
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
                .overlay(
                    Text("Offline")
                        .font(.caption)
                        .padding(4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .offset(x: -8, y: -8),
                    alignment: .topTrailing
                )
            StatusIndicator(isActive: device.isActive)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: deleteAction) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct OldDeviceAlertView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Outdated Device Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text("The scanned QR code is from an older version of Cider. Please update your Cider client to the latest version to use this remote.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("OK") {
                    isPresented = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .frame(width: 320)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct FriendlyNamePromptView: View {
    @EnvironmentObject var viewModel: DeviceListViewModel
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @State private var friendlyName: String = ""
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 50))
                    .foregroundColor(colorScheme.primaryColor)
                
                Text("New Device Found")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Please enter a friendly name for this device:")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Friendly Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("e.g. Living Room PC", text: $friendlyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    viewModel.showingNamePrompt = false
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Add Device") {
                    viewModel.addNewDevice(withName: friendlyName)
                    viewModel.showingNamePrompt = false
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(friendlyName.isEmpty)
            }
        }
        .padding(24)
        .background(systemColorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(width: 320)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject var colorScheme: ColorSchemeManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(colorScheme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
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

struct ConnectionGuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Prerequisites:")
                        .font(.headline)
                    BulletedList(items: [
                        "Cider 2.5.3+ is installed (... > Updates)",
                        "Cider installed and running on your computer (Windows, macOS, or Linux)",
                        "Your Device and Cider on the same local network (If using LAN)",
                        "Cider's RPC & WebSocket server enabled (Settings > Connectivity)"
                    ])
                    
                    Text("Connection Steps:")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 15) {
                        GuideStep(number: 1, text: "Open Cider Remote: Launch the Cider Remote app on your iPhone.")
                        GuideStep(number: 2, text: "Prepare Cider: Open Cider on your Computer, tap the '...' menu, and visit 'Help > Connect a Remote' and create a device. (Some devices may prefer WAN over LAN.)")
                        GuideStep(number: 3, text: "Scan QR Code: In Cider Remote, tap 'Add a New Cider Device' and use the camera to scan the QR code displayed in Cider.")
                        GuideStep(number: 4, text: "Confirm Connection: Your iPhone should now be paired with Cider.")
                    }
                    
                    Text("Troubleshooting:")
                        .font(.headline)
                    Text("If you can't connect:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Ensure both devices are on the same network",
                        "Check if Cider's RPC server is running (port 10767)",
                        "Restart both Cider and Cider Remote",
                        "Check firewall settings (see below)"
                    ])
                    
                    Text("Firewall Settings:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Windows: Allow Cider through Windows Defender Firewall (Inbound Port 10767)",
                        "macOS: Add Cider to allowed apps in Security & Privacy > Firewall",
                        "Linux: Use your distribution's firewall tool to allow port 10767"
                    ])
                    
                    Text("For QR code scanning issues:")
                        .font(.subheadline)
                    BulletedList(items: [
                        "Ensure the code is clearly visible and well-lit",
                        "Try adjusting the distance between your phone and the screen"
                    ])
                    
                    Text("For further assistance, please visit our support forum or GitHub issues page.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitle("Connection Guide", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct GuideStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.blue))
            
            Text(text)
        }
    }
}

struct BulletedList: View {
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                    Text(item)
                }
            }
        }
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
        let osType = device.os ?? device.platform
        switch osType.lowercased() {
        case "win32":
            return UIImage(named: "Windows") ?? UIImage(systemName: "desktopcomputer")!
        case "darwin":
            return UIImage(named: "macOS") ?? UIImage(systemName: "desktopcomputer")!
        case "linux":
            return UIImage(named: "Linux") ?? UIImage(systemName: "desktopcomputer")!
        default:
            return UIImage(systemName: "desktopcomputer")!
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
    @Environment(\.presentationMode) var presentationMode

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
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
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
