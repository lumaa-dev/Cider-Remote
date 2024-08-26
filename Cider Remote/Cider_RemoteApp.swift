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

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    
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
            }
        }
    }
}

protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScanningDidFail()
    func qrScanningSucceededWithCode(_ str: String?)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: QRScannerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
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
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Start running the capture session on a background thread
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    func failed() {
        delegate?.qrScanningDidFail()
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            if metadataObject.type == .qr {
                delegate?.qrScanningSucceededWithCode(metadataObject.stringValue)
            }
        }
    }
}

struct Device: Identifiable, Codable, Hashable {
    let id = UUID()
    let host: String
    let token: String
    let friendlyName: String
    let creationTime: Int
    let version: String
    let platform: String
    let backend: String

    var isActive: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, host, token, friendlyName, creationTime, version, platform, backend
    }
    
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
            devices = decodedDevices
        }
    }
    
    private func saveDevices() {
        if let encodedDevices = try? JSONEncoder().encode(devices) {
            savedDevicesData = encodedDevices
        }
    }
    
    func deleteDevice(device: Device) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices.remove(at: index)
            saveDevices()
        }
    }
    
    func fetchDevices(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: Device.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Error decoding JSON: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] decodedDevice in
                if !(self?.devices.contains(where: { $0.id == decodedDevice.id }))! {
                    self?.devices.append(decodedDevice)
                    self?.saveDevices()
                    // TODO: Handle Migrations for updated info.
                }
                self?.checkDeviceActivity(device: decodedDevice)
            }
            .store(in: &cancellables)
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
            .sink { completion in
                switch completion {
                case .finished:
                    self.finishRefreshing()
                case .failure(let error):
                    print("Error checking device activity: \(error.localizedDescription)")
                    self.finishRefreshing()
                }
            } receiveValue: { [weak self] httpResponse in
                if let index = self?.devices.firstIndex(where: { $0.id == device.id }) {
                    print("Device activity for \(device.friendlyName): \(httpResponse?.statusCode ?? 0)")
                    self?.devices[index].isActive = (httpResponse?.statusCode == 200)
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
