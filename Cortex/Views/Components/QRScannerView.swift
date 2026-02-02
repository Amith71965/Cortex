import SwiftUI
import AVFoundation
import SwiftData

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var scannedURL: String = ""
    @State private var showingBookmarkForm = false
    @State private var isScanning = true
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview background
                CameraPreviewView(onQRDetected: handleQRDetection)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    // Scanning frame
                    scanningFrame
                    
                    Spacer()
                    
                    // Instructions and controls
                    controlsSection
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual Entry") {
                        showingBookmarkForm = true
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingBookmarkForm) {
            AddBookmarkView()
        }
        .alert("QR Code Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var scanningFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 250)
            
            VStack {
                HStack {
                    scannerCorner
                    Spacer()
                    scannerCorner.rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    scannerCorner.rotationEffect(.degrees(270))
                    Spacer()
                    scannerCorner.rotationEffect(.degrees(180))
                }
            }
            .frame(width: 250, height: 250)
            .padding(20)
            
            if isScanning {
                scanLine
            }
        }
    }
    
    private var scannerCorner: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 30))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 30, y: 0))
        }
        .stroke(CortexColors.accents.electricBlue, lineWidth: 4)
        .frame(width: 30, height: 30)
    }
    
    private var scanLine: some View {
        Rectangle()
            .fill(CortexColors.accents.electricBlue.opacity(0.7))
            .frame(height: 2)
            .frame(width: 220)
            .offset(y: scanLineOffset)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: scanLineOffset)
    }
    
    @State private var scanLineOffset: CGFloat = -100
    
    private var controlsSection: some View {
        VStack(spacing: 20) {
            // Instructions
            VStack(spacing: 8) {
                Text("Position QR code within the frame")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("The QR code will be scanned automatically")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(isScanning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isScanning ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isScanning)
                
                Text(isScanning ? "Scanning..." : "Paused")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.horizontal)
        .padding(.bottom, 50)
    }
    
    private func handleQRDetection(_ urlString: String) {
        guard isScanning else { return }
        
        // Validate URL
        guard let url = URL(string: urlString), 
              url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
            errorMessage = "The QR code does not contain a valid web URL"
            showingError = true
            return
        }
        
        isScanning = false
        scannedURL = urlString
        
        // Create bookmark from scanned URL
        createBookmarkFromQR(url: url)
    }
    
    private func createBookmarkFromQR(url: URL) {
        // Generate a title from the URL
        let title = url.host?.capitalized ?? "Scanned Website"
        
        let bookmark = Bookmark(
            title: title,
            url: url,
            notes: "Added via QR code scan"
        )
        
        modelContext.insert(bookmark)
        
        do {
            try modelContext.save()
            
            // Process with AI if auto-organize is enabled
            let autoOrganizeEnabled = UserDefaults.standard.bool(forKey: "autoOrganizeEnabled")
            if autoOrganizeEnabled {
                Task {
                    await AITaggingService.shared.processBookmark(bookmark, modelContext: modelContext)
                }
            }
            
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            errorMessage = "Failed to save bookmark: \(error.localizedDescription)"
            showingError = true
            isScanning = true
        }
    }
    
    private func resumeScanning() {
        isScanning = true
        scanLineOffset = -100
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let onQRDetected: (String) -> Void
    
    func makeUIView(context: Context) -> CameraPreview {
        let preview = CameraPreview()
        preview.onQRDetected = onQRDetected
        return preview
    }
    
    func updateUIView(_ uiView: CameraPreview, context: Context) {}
}

class CameraPreview: UIView {
    var onQRDetected: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            setupCamera()
        } else {
            stopSession()
        }
    }
    
    private func setupCamera() {
        guard captureSession == nil else { return }
        
        let session = AVCaptureSession()
        captureSession = session
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = bounds
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
            
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
        } catch {
            print("Failed to setup camera: \(error)")
        }
    }
    
    private func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
}

extension CameraPreview: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Haptic feedback
            HapticManager.shared.impact(.medium)
            
            onQRDetected?(stringValue)
        }
    }
}

#Preview {
    QRScannerView()
}