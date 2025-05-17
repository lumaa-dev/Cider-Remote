//
//  ContentView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var colorScheme = ColorSchemeManager()
    @StateObject private var deviceListViewModel = DeviceListViewModel()

    @State private var showingSettings = false

    var body: some View {
        ZStack {
            NavigationStack {
                DevicesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                self.showingSettings.toggle()
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .tint(Color.cider)

            if deviceListViewModel.showingNamePrompt {
                FriendlyNamePromptView()
                    .environmentObject(deviceListViewModel)
            }
            
            if deviceListViewModel.showingOldDeviceAlert {
                OldDeviceAlertView()
                    .environmentObject(deviceListViewModel)
            }
        }
        .environmentObject(colorScheme)
        .environmentObject(deviceListViewModel)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct OldDeviceAlertView: View {
    @EnvironmentObject var viewModel: DeviceListViewModel

    var prompt: Prompt {
        var p: Prompt = Prompt(
            symbol: "exclamationmark.triangle",
            title: "Incompatible Device",
            view: AnyView(self.txt),
            actionLabel: "OK",
            action: {}
        )
        return p.cancellable(false)
    }

    var body: some View {
        FullPrompt(isShowing: $viewModel.showingOldDeviceAlert, prompt: prompt)
    }

    var txt: some View {
        Text("The scanned QR code is from an older version of Cider. Please update your Cider client to the latest version to use this remote.")
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

struct FriendlyNamePromptView: View {
    @Environment(\.colorScheme) var systemColorScheme

    @EnvironmentObject var viewModel: DeviceListViewModel

    @State private var friendlyName: String = ""

    var prompt: Prompt {
        return .init(symbol: "desktopcomputer", title: "New Device Found", view: AnyView(self.fields), actionLabel: "OK", action: {
            viewModel.addNewDevice(withName: friendlyName)
            viewModel.showingNamePrompt = false
        })
    }

    var body: some View {
        FullPrompt(isShowing: $viewModel.showingNamePrompt.animation(.spring), prompt: prompt)
    }

    @ViewBuilder
    var fields: some View {
        Text("Please enter a friendly name for this device:")
            .font(.subheadline)
            .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: 8) {
            Text("Friendly Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. Living Room PC", text: $friendlyName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.words)
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

struct StatusIndicator: View {
    let status: DeviceStatus

    var color: Color {
        switch status {
            case .offline:
                Color.red
            case .online:
                Color.green
            case .refreshing:
                Color.clear
        }
    }

    var body: some View {
        if status != DeviceStatus.refreshing {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: color.opacity(0.5), radius: 2)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: 12, height: 12)
        }
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
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitle("Connection Guide")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
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

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundStyle(.red)
                .offset(x: 60)
        }
        .padding()
    }
}

enum DeviceStatus {
    case offline
    case online
    case refreshing
}

#Preview {
    ContentView()
}
