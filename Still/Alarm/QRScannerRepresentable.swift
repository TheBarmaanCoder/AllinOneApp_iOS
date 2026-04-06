import AVFoundation
import SwiftUI

struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onFound = onFound
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?
    private var session: AVCaptureSession?
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        startSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func startSession() {
        guard session == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .high
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }

        self.session = session
        previewLayer.session = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue
        else { return }
        StillHaptics.selectionChanged()
        onFound?(value)
    }

    deinit {
        session?.stopRunning()
    }
}
