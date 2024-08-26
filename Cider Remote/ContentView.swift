//
//  ContentView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct ContentView: View {
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
    }
}

struct DevicesView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var selectedDevice: Device?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    DeviceListView(viewModel: viewModel, selectedDevice: $selectedDevice)
                    RefreshingView(isRefreshing: viewModel.isRefreshing)
                    AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode, viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(uiImage: UIImage(named: "Logo")!)
                            .resizable()
                            .scaledToFit()
                            .padding(5)
                        Text("Cider Remote")
                            .font(.headline)
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

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(uiImage: UIImage(named: "Logo")!)
                .resizable()
                .scaledToFit()
            Text("Cider Remote")
                .font(.headline)
        }
        .frame(height: 30)
    }
}

struct DeviceListView: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @Binding var selectedDevice: Device?
    
    var body: some View {
        ForEach(viewModel.devices) { device in
            NavigationLink(
                destination: MusicPlayerView(
                    device: device,
                    viewModel: MusicPlayerViewModel(device: device)
                ),
                tag: device,
                selection: $selectedDevice
            ) {
                DeviceRowView(device: device, onDelete: {
                    viewModel.deleteDevice(device: device)
                })
            }
        }
    }
}

struct DeviceRowView: View {
    let device: Device
    let onDelete: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 100)
            .padding()
            .overlay {
                HStack {
                    DeviceIconView(device: device)
                    DeviceInfoView(device: device)
                    DeleteButton(action: onDelete)
                }
            }
    }
}

struct DeviceIconView: View {
    let device: Device
    
    var body: some View {
        ZStack {
            Image(uiImage: deviceImage)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(device.isActive ? .green : .red)
                .offset(x: -60)
        }
    }
    
    var deviceImage: UIImage {
        switch device.platform {
        case "win32": return UIImage(named: "Windows")!
        case "darwin": return UIImage(named: "macOS")!
        case "linux": return UIImage(named: "Linux")!
        default: return UIImage()
        }
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
        VStack {
            Text("Can't find your device?")
                .padding()
            Button(action: {
                isShowingScanner = true
            }) {
                Image(systemName: "qrcode")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Scan QR Code")
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
}

struct SettingsView: View {
    var body: some View {
        Text("Settings View")
    }
}

#Preview {
    ContentView()
}
