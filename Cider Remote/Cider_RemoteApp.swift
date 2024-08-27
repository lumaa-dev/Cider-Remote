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


class Device: Identifiable, Codable, ObservableObject, Hashable {
    @Published var id: UUID
    let host: String
    let token: String
    let friendlyName: String
    let creationTime: Int
    let version: String
    let platform: String
    let backend: String

    @Published var isActive: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, host, token, friendlyName, creationTime, version, platform, backend, isActive
    }

    init(id: UUID = UUID(), host: String, token: String, friendlyName: String, creationTime: Int, version: String, platform: String, backend: String, isActive: Bool = false) {
        self.id = id
        self.host = host
        self.token = token
        self.friendlyName = friendlyName
        self.creationTime = creationTime
        self.version = version
        self.platform = platform
        self.backend = backend
        self.isActive = isActive
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        host = try container.decode(String.self, forKey: .host)
        token = try container.decode(String.self, forKey: .token)
        friendlyName = try container.decode(String.self, forKey: .friendlyName)
        creationTime = try container.decode(Int.self, forKey: .creationTime)
        version = try container.decode(String.self, forKey: .version)
        platform = try container.decode(String.self, forKey: .platform)
        backend = try container.decode(String.self, forKey: .backend)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
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
        try container.encode(isActive, forKey: .isActive)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}

class DeviceListViewModel: ObservableObject {
    @AppStorage("savedDevices") private var savedDevicesData: Data = Data()
    @Published var devices: [Device] = []
    @Published var isRefreshing: Bool = false

    private var activityCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadDevices()
    }

    private func loadDevices() {
        if let decodedDevices = try? JSONDecoder().decode([Device].self, from: savedDevicesData) {
            devices = decodedDevices.map { Device(id: $0.id, host: $0.host, token: $0.token, friendlyName: $0.friendlyName, creationTime: $0.creationTime, version: $0.version, platform: $0.platform, backend: $0.backend, isActive: $0.isActive) }
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

    func fetchDevices(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return
            }

            print("Response status code: \(httpResponse.statusCode)")

            guard let data = data, !data.isEmpty else {
                print("Empty or nil data received")
                return
            }

            print("Received data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")

            do {
                let decodedDevice = try JSONDecoder().decode(Device.self, from: data)
                DispatchQueue.main.async {
                    if let existingIndex = self?.devices.firstIndex(where: { $0.host == decodedDevice.host }) {
                        // Update existing device
                        self?.devices[existingIndex] = decodedDevice
                    } else {
                        // Add new device
                        self?.devices.append(decodedDevice)
                    }
                    self?.saveDevices()
                    self?.checkDeviceActivity(device: decodedDevice)
                }
            } catch {
                print("Error decoding JSON: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type \(type): \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value of type \(type) not found: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
            }
        }.resume()
    }

    func checkDeviceActivity(device: Device) {
        guard let url = URL(string: "http://\(device.host):10767/api/v1/playback/active") else {
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
                    self?.finishRefreshing()
                }
            } receiveValue: { [weak self] httpResponse in
                if let index = self?.devices.firstIndex(where: { $0.id == device.id }) {
                    let isActive = (httpResponse?.statusCode == 200)
                    print("Device activity for \(device.friendlyName): \(httpResponse?.statusCode ?? 0), isActive: \(isActive)")
                    DispatchQueue.main.async {
                        self?.devices[index].isActive = isActive
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func finishRefreshing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }

    func startActivityChecking() {
        // Check first without delay
        for device in self.devices {
            self.checkDeviceActivity(device: device)
        }

        // Schedule refreshes every 10 seconds
        activityCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
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
