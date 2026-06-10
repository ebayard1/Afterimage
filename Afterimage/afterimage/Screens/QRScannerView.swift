import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            QRScannerRepresentable(onScanned: { code in
                onScanned(code)
                dismiss()
            })
            .ignoresSafeArea()

            // Reticle
            VStack {
                Spacer()
                ZStack {
                    Rectangle().stroke(Palette.gold, lineWidth: 2)
                        .frame(width: 220, height: 220)
                    ForEach(0..<4) { i in
                        Rectangle()
                            .fill(Palette.gold)
                            .frame(width: 24, height: 4)
                            .offset(corner(i, axis: .horizontal))
                        Rectangle()
                            .fill(Palette.gold)
                            .frame(width: 4, height: 24)
                            .offset(corner(i, axis: .vertical))
                    }
                }
                Spacer()
                Text("point at an album QR code")
                    .font(.system(size: 12)).italic()
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 28)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
    }

    private func corner(_ i: Int, axis: Axis) -> CGSize {
        let half: CGFloat = 110 - 2
        switch (i, axis) {
        case (0, .horizontal): return .init(width: -half + 12, height: -half)
        case (0, .vertical):   return .init(width: -half, height: -half + 12)
        case (1, .horizontal): return .init(width:  half - 12, height: -half)
        case (1, .vertical):   return .init(width:  half, height: -half + 12)
        case (2, .horizontal): return .init(width: -half + 12, height:  half)
        case (2, .vertical):   return .init(width: -half, height:  half - 12)
        case (3, .horizontal): return .init(width:  half - 12, height:  half)
        case (3, .vertical):   return .init(width:  half, height:  half - 12)
        default: return .zero
        }
    }

    private enum Axis { case horizontal, vertical }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerVC {
        let vc = QRScannerVC()
        vc.onScanned = onScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerVC, context: Context) {}
}

final class QRScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didScan = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    private func setup() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didScan,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didScan = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScanned?(value)
    }
}
