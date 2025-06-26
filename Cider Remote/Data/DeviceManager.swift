// Made by Lumaa

import Foundation

class DeviceManager: ObservableObject {
    static let shared: DeviceManager = .init()

    @Published private(set) public var devices: [Device] = []
    public var connectionInfo: ConnectionInfo?

    init(devices: [Device]) {
        self.devices = devices
    }

    init() {
        self.devices = self.loadDevices()
    }

    func add(_ device: Device) {
        self.devices.append(device)
        self.saveDevices()
    }

    func set(_ device: Device, at: Int) {
        self.devices[at] = device
        self.saveDevices()
    }

    func remove(_ device: Device) {
        self.devices.removeAll { $0.id == device.id }
        self.saveDevices()
    }

    func clear() {
        self.devices.removeAll()
        self.saveDevices()
    }

    func checkDeviceActivity(_ device: Device) async {
        defer { device.isRefreshing = false }

        guard let url = URL(string: "\(device.fullAddress)/api/v1/playback/active") else {
            print("Invalid URL for device: \(device.friendlyName)")
            return
        }

        var request = URLRequest(url: url)
        request.addValue(device.token, forHTTPHeaderField: "apptoken")

        device.isRefreshing = true

        if let activity = try? await URLSession.shared.data(for: request), let httpurl: HTTPURLResponse = activity.1 as? HTTPURLResponse {
            device.isActive = httpurl.statusCode == 200
        } else {
            device.isActive = false
        }
    }

    private func saveDevices() {
        if let encodedDevices = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encodedDevices, forKey: "savedDevices")
            UserDefaults.main.set(encodedDevices, forKey: "savedDevices")
        }
    }

    private func loadDevices() -> [Device] {
        guard let savedDevicesData: Data = UserDefaults.standard.data(forKey: "savedDevices") else { return [] }

        do {
            let decoder = JSONDecoder()
            let decodedDevices: [Device] = try decoder.decode([Device].self, from: savedDevicesData)
            return decodedDevices
        } catch {
            print("Error decoding saved devices: \(error)")
            return []
        }
    }
}
