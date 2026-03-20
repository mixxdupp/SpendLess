import SwiftUI
import AVFoundation
import PhotosUI

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseService: PurchaseService
    
    @State private var currentStep = 0
    @State private var urlText = ""
    @State private var titleText = ""
    @State private var priceText = ""
    @State private var imageUrl: String? = nil
    @State private var currency: String = "USD"
    @State private var cooldownDays = 7
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    let onProductAdded: (Product) -> Void
    
    private let steps = ["URL", "Details", "Cooldown"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                StepProgressView(currentStep: currentStep, steps: steps)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Step content
                TabView(selection: $currentStep) {
                    urlStep.tag(0)
                    detailsStep.tag(1)
                    cooldownStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                            generateHaptic(.light)
                        } label: {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                    
                    Button {
                        handleNext()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(currentStep == 2 ? "Add Product" : "Next")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canProceed ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(!canProceed || isLoading)
                    .buttonStyle(BouncyButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Track Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear {
                checkClipboard()
            }
        }
    }
    
    // MARK: - Step 1: URL Input
    private var urlStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "link.badge.plus")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("Paste Product Link")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("From any shopping website")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                TextField("https://...", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                // Camera Scan Button
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(BouncyButtonStyle())
                
                // Direct Image Upload Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let newItem = newItem,
                           let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            
                            isLoading = true // Show loading
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            // Analyze
                            let result = await ProductScannerService.shared.analyze(image: image)
                            
                            // Process
                            do {
                                if let metadata = try await ProductScannerService.shared.processScanResult(result) {
                                    if let title = metadata.title { titleText = title }
                                    if let price = metadata.price { priceText = "\(price)" }
                                    if let img = metadata.imageUrl { imageUrl = img }
                                    if let curr = metadata.currency { currency = curr }
                                    
                                    // Success! Move to details
                                    withAnimation {
                                        currentStep = 1
                                    }
                                } else {
                                    // Found nothing
                                    errorMessage = "Could not detect product. Please enter manually."
                                    generator.notificationOccurred(.error)
                                }
                            } catch {
                                errorMessage = "Scan failed: \(error.localizedDescription)"
                                generator.notificationOccurred(.error)
                            }
                            
                            isLoading = false
                            selectedPhotoItem = nil // Reset
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .sheet(isPresented: $showCamera) {
                CameraScannerView { metadata in
                     if let title = metadata.title { titleText = title }
                     if let price = metadata.price { priceText = "\(price)" }
                     if let img = metadata.imageUrl { imageUrl = img }
                     if let curr = metadata.currency { currency = curr }
                     
                     // Skip to Details step
                     withAnimation {
                         currentStep = 1
                     }
                }
            }
            
            if UIPasteboard.general.hasURLs {
                Button {
                    if let url = UIPasteboard.general.url {
                        urlText = url.absoluteString
                        generateHaptic(.medium)
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.subheadline)
                }
            }
            
            // Skip Button for Manual Entry
            Button {
                handleSkip()
            } label: {
                Text("No link? Enter manually")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, 8)
            
            Spacer()
            Spacer()
        }
    }
    
    private func handleSkip() {
        // Use a dummy URL for manual entries since the DB likely requires one
        urlText = "https://manual-entry-\(UUID().uuidString.prefix(8)).com"
        generateHaptic(.light)
        withAnimation {
            currentStep += 1
        }
    }
    
    // MARK: - Step 2: Product Details
    private var detailsStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("Product Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Auto-fill may not work for all sites.\nFill in manually if needed.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                TextField("Product name", text: $titleText)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Current price", text: $priceText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Step 3: Cooldown Selection
    private var cooldownStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated clock icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Set Your Cooldown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("How long to wait before price alerts?\nThis prevents impulse buying.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Visual cooldown picker
            VStack(spacing: 16) {
                Text("\(cooldownDays) days")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Slider(value: Binding(
                    get: { Double(cooldownDays) },
                    set: { cooldownDays = Int($0) }
                ), in: 1...30, step: 1)
                .tint(.orange)
                .padding(.horizontal, 32)
                
                HStack {
                    Text("1 day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("30 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Helpers
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !urlText.isEmpty && isValidURL(urlText)
        case 1: return true // Details are optional
        case 2: return true
        default: return false
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    private func handleNext() {
        errorMessage = nil
        
        if currentStep == 0 {
            // Fetch metadata before moving to details
            Task {
                isLoading = true
                defer { isLoading = false }
                
                // Try to fetch metadata (don't block if it fails)
                if let metadata = try? await MetadataFetcher.shared.fetchMetadata(for: urlText) {
                    if let title = metadata.title { titleText = title }
                    if let price = metadata.price { priceText = "\(price)" }
                    if let img = metadata.imageUrl { imageUrl = img }
                    if let curr = metadata.currency { currency = curr }
                    generateHaptic(.medium)
                }
                
                withAnimation {
                    currentStep += 1
                }
            }
        } else if currentStep == 1 {
            withAnimation {
                currentStep += 1
            }
            generateHaptic(.light)
        } else {
            Task {
                await addProduct()
            }
        }
    }
    
    private func checkClipboard() {
        if let url = UIPasteboard.general.url {
            urlText = url.absoluteString
        }
    }
    
    private func generateHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func addProduct() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let price: Decimal? = priceText.isEmpty ? nil : Decimal(string: priceText)
        
        do {
            let product = try await APIClient.shared.addProduct(
                url: urlText,
                title: titleText.isEmpty ? nil : titleText,
                price: price,
                imageUrl: imageUrl,
                currency: currency,
                cooldownDays: cooldownDays
            )
            
            generateHaptic(.medium)
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
            
            onProductAdded(product)
            dismiss()
        } catch APIError.productLimitReached {
            showPaywall = true
        } catch {
            errorMessage = error.localizedDescription
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Step Progress Indicator
struct StepProgressView: View {
    let currentStep: Int
    let steps: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(spacing: 0) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 28, height: 28)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(index == currentStep ? .white : .secondary)
                        }
                    }
                    
                    // Connector line
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color(.systemGray4))
                            .frame(height: 2)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: currentStep)
    }
}

#Preview {
    AddProductView { _ in }
}
import SwiftUI
import AVFoundation

import PhotosUI

struct CameraScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (ProductMetadata) -> Void
    
    @StateObject private var camera = CameraModel()
    
    // Photo Library Selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var isAnalyzingPhoto = false
    
    var body: some View {
        ZStack {
            // Camera Preview
            #if targetEnvironment(simulator)
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                Text("Camera not available in Simulator")
                    .foregroundStyle(.white)
                    .padding()
                Spacer()
            }
            #else
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            #endif
            
            // Overlays
            VStack {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    Spacer()
                    
                    // Photo Library Picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let newItem = newItem,
                               let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                
                                isAnalyzingPhoto = true
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success) // Acknowledge selection
                                
                                // Analyze
                                let result = await ProductScannerService.shared.analyze(image: image)
                                
                                // Process
                                if let metadata = try? await ProductScannerService.shared.processScanResult(result) {
                                    onResult(metadata)
                                    dismiss()
                                }
                                isAnalyzingPhoto = false
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    Text("Scan Product")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(camera.isProcessing || isAnalyzingPhoto ? "Analyzing..." : "Point at Barcode or Front of Box")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 32)
                
                // Capture Button
                Button {
                    camera.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        if camera.isProcessing || isAnalyzingPhoto {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                }
                .padding(.bottom, 50)
                .disabled(camera.isProcessing || isAnalyzingPhoto)
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onChange(of: camera.foundMetadata) { _, metadata in
            if let meta = metadata {
                generateHaptic()
                onResult(meta)
                dismiss()
            }
        }
    }
    
    private func generateHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Camera Model
@MainActor
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    @Published var session = AVCaptureSession()
    @Published var isProcessing = false
    @Published var foundMetadata: ProductMetadata?
    
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    
    func checkPermissions() {
        #if targetEnvironment(simulator)
        print("📷 [Camera] Simulator detected. Skipping camera setup.")
        // Mock a success or handle UI
        return
        #endif
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.setupCamera() }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        queue.async {
            self.session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            
            if self.session.canAddInput(input) { self.session.addInput(input) }
            
            // Photo Output (for Vision/Text)
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            
            // Metadata Output (for Live Barcodes)
            if self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                self.metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .upce]
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func capturePhoto() {
        // Manual capture for text/products without barcodes
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        DispatchQueue.main.async { self.isProcessing = true }
    }
    
    // Delegate Method: Live Barcode Scanning
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            
            // Stop scanning immediately to prevent duplicate triggers
            isProcessing = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
             
            Task {
                print("📦 [Live Scanner] Found Barcode: \(stringValue)")
                // Directly fetch details for barcode
                let metadata = try? await MetadataFetcher.shared.findProductDetails(fromQuery: stringValue)
                
                DispatchQueue.main.async {
                    self.foundMetadata = metadata
                    // Keep isProcessing true so we don't scan again until dismissed
                }
            }
        }
    }
    
    // Delegate Method: Photo Capture (For Vision/Fallback)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.isProcessing = false }
            return
        }
        
        Task {
            // 1. Vision Analysis (Barcode/Text)
            let result = await ProductScannerService.shared.analyze(image: image)
            
            // 2. Fetch Metadata
            do {
                if let metadata = try await ProductScannerService.shared.processScanResult(result) {
                    DispatchQueue.main.async {
                        self.foundMetadata = metadata
                        self.isProcessing = false
                    }
                } else {
                    print("No product found")
                    DispatchQueue.main.async { self.isProcessing = false }
                }
            } catch {
                print("Error fetching metadata: \(error)")
                DispatchQueue.main.async { self.isProcessing = false }
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
