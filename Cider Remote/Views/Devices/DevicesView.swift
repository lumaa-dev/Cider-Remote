// Made by Lumaa

import SwiftUI

struct DevicesView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    @StateObject private var deviceManager: DeviceManager = .shared

    @State var isRefreshing: Bool = false

    @AppStorage("autoRefresh") private var autoRefresh: Bool = true
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0

    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var isShowingGuide = false

    @State private var activityCheckTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                ForEach(deviceManager.devices) { device in
                    if device.isActive {
                        NavigationLink(value: device) {
                            DeviceRowView(device: device)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deviceManager.remove(device)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        if autoRefresh {
                            DeviceRowView(device: device)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deviceManager.remove(device)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            Button {
                                Task {
                                    await self.refreshDevice(device)
                                }
                            } label: {
                                HStack {
                                    DeviceRowView(device: device)

                                    Spacer()

                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(Color(uiColor: UIColor.tertiaryLabel))
                                }
                            }
                            .tint(Color(uiColor: UIColor.label))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deviceManager.remove(device)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode) { json in
                    self.fetchDevices(from: json)
                }

                Button(action: {
                    isShowingGuide = true
                }) {
                    Label("Connection Guide", systemImage: "questionmark.circle")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .task {
                await self.refreshDevices()
            }
            .refreshable {
                await self.refreshDevices()
            }
#if DEBUG
            Label("This is a DEBUG version.", systemImage: "gearshape.2.fill")
                .foregroundStyle(.orange)
                .accessibility(label: Text("Debug software"))
#endif
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Device.self) { device in
            LazyView(MusicPlayerView(device: device))
        }
        .sheet(isPresented: $isShowingGuide) {
            ConnectionGuideView()
        }
        .onAppear {
            self.startActivityChecking()
        }
        .onDisappear {
            self.stopActivityChecking()
        }
    }

    var header: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)

            Text("Cider Devices")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Material.ultraThick)
    }

    @MainActor
    func refreshDevices() async {
        isRefreshing = true

        for device in deviceManager.devices {
            await deviceManager.checkDeviceActivity(device)
        }

        // Simulate a slight delay to show the refresh indicator
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }

    @MainActor
    func refreshDevice(_ device: Device) async {
        isRefreshing = true

        await deviceManager.checkDeviceActivity(device)

        // Simulate a slight delay to show the refresh indicator
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        isRefreshing = false
    }

    func fetchDevices(from jsonString: String) {
        print("Received JSON string: \(jsonString)")  // Log the received JSON string

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert JSON string to Data")
            AppPrompt.shared.showingPrompt = .oldDevice
            return
        }

        do {
            let connectionInfo = try JSONDecoder().decode(ConnectionInfo.self, from: jsonData)
            deviceManager.connectionInfo = connectionInfo
            AppPrompt.shared.showingPrompt = .newDevice
        } catch {
            print("Error decoding ConnectionInfo: \(error)")
            AppPrompt.shared.showingPrompt = .oldDevice
        }
    }

    func addNewDevice(withName friendlyName: String) {
        guard let connectionInfo = deviceManager.connectionInfo else {
            print("No new device info available")
            return
        }

        let newDevice = Device(
            id: UUID(),
            host: connectionInfo.address,
            token: connectionInfo.token,
            friendlyName: friendlyName,
            creationTime: Int(Date().timeIntervalSince1970),
            version: connectionInfo.initialData.version,
            platform: connectionInfo.initialData.platform,
            backend: connectionInfo.initialData.platform, // Using platform as backend for now
            connectionMethod: connectionInfo.method.rawValue,
            isActive: false,
            os: connectionInfo.initialData.os
        )

        DispatchQueue.main.async {
            if let existingIndex = deviceManager.devices.firstIndex(where: { $0.host == newDevice.host }) {
                // Update existing device
                deviceManager.set(newDevice, at: existingIndex)
            } else {
                // Add new device
                deviceManager.add(newDevice)
            }

            Task { await deviceManager.checkDeviceActivity(newDevice) }
        }

        // Reset the new device info and close the prompt
        deviceManager.connectionInfo = nil
        AppPrompt.shared.showingPrompt = .newDevice
    }

    private func finishRefreshing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }

    func startActivityChecking() {
        guard autoRefresh else { return }

        stopActivityChecking() // Ensure we're not running multiple timers

        // Schedule refreshes based on the refresh interval
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            for device in deviceManager.devices {
                Task { await deviceManager.checkDeviceActivity(device) }
            }
        }
    }

    func stopActivityChecking() {
        guard autoRefresh else { return }

        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }
}
