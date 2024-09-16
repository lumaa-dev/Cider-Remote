//
//  Cider_RemoteApp.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI
import AVFoundation
import Combine

@main
struct Cider_RemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: QRScannerViewControllerDelegate?
    
    private let supportedCodeTypes: [AVMetadataObject.ObjectType] = [.qr]
    private var highlightView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCaptureSession()
        setupPreviewLayer()
        setupHighlightView()
        setupCloseButton()
        startRunning()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = supportedCodeTypes
        } else {
            failed()
            return
        }
    }

    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    private func setupHighlightView() {
        highlightView = UIView()
        highlightView?.layer.borderColor = UIColor.green.cgColor
        highlightView?.layer.borderWidth = 3
        highlightView?.backgroundColor = UIColor.clear
        if let highlightView = highlightView {
            view.addSubview(highlightView)
            view.bringSubviewToFront(highlightView)
        }
    }

    private func setupCloseButton() {
        let closeButtonSize: CGFloat = 44
        let padding: CGFloat = 16

        // Create a backdrop view
        let backdropView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        backdropView.layer.cornerRadius = closeButtonSize / 2
        backdropView.clipsToBounds = true
        view.addSubview(backdropView)

        // Create the close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        // Add the close button to the backdrop
        backdropView.contentView.addSubview(closeButton)

        // Setup constraints
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: padding),
            backdropView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -padding),
            backdropView.widthAnchor.constraint(equalToConstant: closeButtonSize),
            backdropView.heightAnchor.constraint(equalToConstant: closeButtonSize),

            closeButton.centerXAnchor.constraint(equalTo: backdropView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: backdropView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: closeButtonSize)
        ])
    }

    @objc private func closeButtonTapped() {
        delegate?.qrScanningDidStop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func failed() {
        delegate?.qrScanningDidFail()
        captureSession = nil
    }

    private func startRunning() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            guard supportedCodeTypes.contains(metadataObject.type) else { return }

            if metadataObject.type == .qr {
                if let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject) {
                    highlightView?.frame = barCodeObject.bounds
                    highlightView?.isHidden = false
                }
                delegate?.qrScanningSucceededWithCode(metadataObject.stringValue)
            }
        } else {
            highlightView?.isHidden = true
        }
    }
}

protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScanningDidFail()
    func qrScanningSucceededWithCode(_ str: String?)
    func qrScanningDidStop()
}

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        var parent: QRScannerView

        init(_ parent: QRScannerView) {
            self.parent = parent
        }

        func qrScanningDidFail() {
            print("Scanning Failed. Please try again.")
        }

        func qrScanningSucceededWithCode(_ str: String?) {
            if let code = str {
                parent.scannedCode = code
                parent.presentationMode.wrappedValue.dismiss()
            }
        }

        func qrScanningDidStop() {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ConnectionInfo: Codable {
    let address: String
    let token: String
    let method: ConnectionMethod
    let initialData: InitialData
}

enum ConnectionMethod: String, Codable {
    case lan
    case tunnel
}

struct InitialData: Codable {
    let version: String
    let platform: String
    let os: String
    
    // We'll use CodingKeys to handle the missing 'arch' field
    enum CodingKeys: String, CodingKey {
        case version, platform, os
    }
    
    // Custom initializer to set a default value for 'arch'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        platform = try container.decode(String.self, forKey: .platform)
        os = try container.decode(String.self, forKey: .os)
    }
}

class Device: Identifiable, Codable, ObservableObject, Hashable {
    let id: UUID
    let host: String
    let token: String
    let friendlyName: String
    let creationTime: Int
    let version: String
    let platform: String
    let backend: String
    let os: String?
    let connectionMethod: String

    @Published var isActive: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, host, token, friendlyName, creationTime, version, platform, backend, isActive, connectionMethod, os
    }

    init(id: UUID = UUID(), host: String, token: String, friendlyName: String, creationTime: Int, version: String, platform: String, backend: String, connectionMethod: String, isActive: Bool = false, os: String? = nil) {
        self.id = id
        self.host = host
        self.token = token
        self.friendlyName = friendlyName
        self.creationTime = creationTime
        self.version = version
        self.platform = platform
        self.backend = backend
        self.connectionMethod = connectionMethod
        self.isActive = isActive
        self.os = os
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode with fallbacks for optional fields
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        host = try container.decode(String.self, forKey: .host)
        token = try container.decode(String.self, forKey: .token)
        friendlyName = try container.decode(String.self, forKey: .friendlyName)
        creationTime = try container.decode(Int.self, forKey: .creationTime)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "Unknown"
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "Unknown"
        backend = try container.decodeIfPresent(String.self, forKey: .backend) ?? "Unknown"
        
        // For connectionMethod, use "lan" as default if not present
        connectionMethod = try container.decodeIfPresent(String.self, forKey: .connectionMethod) ?? "lan"
        
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        os = try container.decodeIfPresent(String.self, forKey: .os)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(host, forKey: .host)
        try container.encode(token, forKey: .token)
        try container.encode(friendlyName, forKey: .friendlyName)
        try container.encode(creationTime, forKey: .creationTime)
        try container.encode(version, forKey: .version)
        try container.encode(platform, forKey: .platform)
        try container.encode(backend, forKey: .backend)
        try container.encode(connectionMethod, forKey: .connectionMethod)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(os, forKey: .os)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }

    var fullAddress: String {
        switch connectionMethod {
        case "tunnel":
            return "https://\(host)"
        default: // "lan" or any other value
            return "http://\(host):10767"
        }
    }
}

class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isRefreshing: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Double = 10.0
    @Published var showingNamePrompt: Bool = false
    @Published var newDeviceInfo: ConnectionInfo?
    @Published var showingOldDeviceAlert: Bool = false

    @AppStorage("savedDevices") private var savedDevicesData: Data = Data()

    private var activityCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadDevices()
    }
    
    @MainActor
    func refreshDevices() async {
        isRefreshing = true
        
        for device in devices {
            checkDeviceActivity(device: device)
        }
        
        // Simulate a slight delay to show the refresh indicator
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isRefreshing = false
    }

    private func loadDevices() {
        do {
            let decoder = JSONDecoder()
            let decodedDevices = try decoder.decode([Device].self, from: savedDevicesData)
            devices = decodedDevices
        } catch {
            print("Error decoding saved devices: \(error)")
            // If there's an error, clear the saved data to prevent future crashes
            savedDevicesData = Data()
            devices = []
        }
    }

    private func saveDevices() {
        if let encodedDevices = try? JSONEncoder().encode(devices) {
            savedDevicesData = encodedDevices
        }
    }

    func deleteDevice(device: Device) {
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }

    func fetchDevices(from jsonString: String) {
        print("Received JSON string: \(jsonString)")  // Log the received JSON string

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert JSON string to Data")
            self.showingOldDeviceAlert = true
            return
        }

        do {
            let connectionInfo = try JSONDecoder().decode(ConnectionInfo.self, from: jsonData)
            self.newDeviceInfo = connectionInfo
            self.showingNamePrompt = true
        } catch {
            print("Error decoding ConnectionInfo: \(error)")
            self.showingOldDeviceAlert = true
        }
    }

    func addNewDevice(withName friendlyName: String) {
        guard let connectionInfo = self.newDeviceInfo else {
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
            if let existingIndex = self.devices.firstIndex(where: { $0.host == newDevice.host }) {
                // Update existing device
                self.devices[existingIndex] = newDevice
            } else {
                // Add new device
                self.devices.append(newDevice)
            }
            self.saveDevices()
            self.checkDeviceActivity(device: newDevice)
        }

        // Reset the new device info and close the prompt
        self.newDeviceInfo = nil
        self.showingNamePrompt = false
    }


    func checkDeviceActivity(device: Device) {
        guard let url = URL(string: "\(device.fullAddress)/api/v1/playback/active") else {
            print("Invalid URL for device: \(device.friendlyName)")
            return
        }

        var request = URLRequest(url: url)
        request.addValue(device.token, forHTTPHeaderField: "apptoken")


        self.isRefreshing = true

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.response)
            .map { $0 as? HTTPURLResponse }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    self?.finishRefreshing()
                case .failure(let error):
                    print("Error checking device activity: \(error.localizedDescription)")
                    self?.updateDeviceStatus(device: device, isActive: false)
                    self?.finishRefreshing()
                }
            } receiveValue: { [weak self] httpResponse in
                let isActive = (httpResponse?.statusCode == 200)
                print("Device activity for \(device.friendlyName): \(httpResponse?.statusCode ?? 0), isActive: \(isActive)")
                self?.updateDeviceStatus(device: device, isActive: isActive)
            }
            .store(in: &cancellables)
    }

    private func updateDeviceStatus(device: Device, isActive: Bool) {
        DispatchQueue.main.async {
            if let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                self.devices[index].isActive = isActive
                self.objectWillChange.send()
            }
        }
    }

    private func finishRefreshing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }

    func startActivityChecking() {
        stopActivityChecking() // Ensure we're not running multiple timers

        // Check first without delay
        for device in self.devices {
            self.checkDeviceActivity(device: device)
        }

        // Schedule refreshes based on the refresh interval
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for device in self.devices {
                self.checkDeviceActivity(device: device)
            }
        }
    }

    func stopActivityChecking() {
        activityCheckTimer?.invalidate()
        activityCheckTimer = nil
    }
}
