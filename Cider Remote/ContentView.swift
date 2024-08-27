//
//  ContentView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var colorScheme = ColorSchemeManager()
    var body: some View {
        TabView {
            DevicesView()
                .tabItem {
                    Text("Devices")
                    Image(systemName: "laptopcomputer")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                }
            SettingsView()
                .tabItem {
                    Text("Settings")
                    Image(systemName: "gear")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                }
        }
        .accentColor(colorScheme.useAdaptiveColors ? colorScheme.primaryColor : Color(hex: "#fa2f48"))
        .environmentObject(colorScheme)
    }
}

struct DevicesView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var selectedDevice: Device?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CiderHeaderView()
                
                List {
                    ForEach(viewModel.devices) { device in
                        NavigationLink(
                            destination: MusicPlayerView(
                                device: device,
                                viewModel: MusicPlayerViewModel(device: device)
                            ),
                            tag: device,
                            selection: $selectedDevice
                        ) {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.startActivityChecking()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            viewModel.startActivityChecking()
        }
        .onDisappear {
            viewModel.stopActivityChecking()
        }
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

struct SettingsView: View {
    var body: some View {
        Text("Settings View")
    }
}

#Preview {
    ContentView()
}
