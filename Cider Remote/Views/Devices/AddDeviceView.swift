// Made by Lumaa

import SwiftUI
import AVFoundation

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
                .overlay(alignment: .top) {
                    Text("Scan the Cider QR code")
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 7.5)
                        .background(Material.thin)
                        .clipShape(.rect(cornerRadius: 15.5))
                        .padding(.top, 22.5)
                }
        }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                viewModel.fetchDevices(from: code)
                isShowingScanner = false
            }
        }
    }
}

// MARK: QR Code stuff

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
