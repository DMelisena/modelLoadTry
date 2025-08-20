import PhotosUI
import SwiftUI
import YOLO
import Foundation

// MARK: - Models
struct YOLOModel {
    let name: String
    let url: String?
    let task: YOLOTask
    let isRemote: Bool
    
    init(name: String, task: YOLOTask = .detect) {
        self.name = name
        self.url = nil
        self.task = task
        self.isRemote = false
    }
    
    init(name: String, url: String, task: YOLOTask = .detect) {
        self.name = name
        self.url = url
        self.task = task
        self.isRemote = true
    }
}

enum YOLOTask {
    case detect
    case segment
    case classify
}

struct ImageProcessingResult {
    let originalImage: UIImage
    let processedImage: UIImage
    let yoloResult: YOLOResult
}

enum ModelLoadingState {
    case idle
    case loading
    case loaded(YOLO)
    case failed(Error)
}

// MARK: - Services
protocol ModelDownloadServiceProtocol {
    func downloadModel(from url: String, fileName: String) async throws -> URL
    func getCachedModelURL(fileName: String) -> URL?
    func isModelCached(fileName: String) -> Bool
}

class ModelDownloadService: ModelDownloadServiceProtocol {
    private let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    func downloadModel(from urlString: String, fileName: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if urlString.hasSuffix(".zip") {
            // For ZIP files, we'll throw a helpful error for now
            // In a production app, you'd want to implement proper ZIP extraction
            throw NSError(domain: "ModelDownloadService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "ZIP files are not supported. Please provide a direct .mlmodel file URL."
            ])
        } else {
            let localURL = cacheDirectory.appendingPathComponent(fileName)
            try data.write(to: localURL)
            return localURL
        }
    }
    
    func getCachedModelURL(fileName: String) -> URL? {
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }
    
    func isModelCached(fileName: String) -> Bool {
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
}

protocol ImageProcessingServiceProtocol {
    func correctImageOrientation(_ image: UIImage) -> UIImage
    func processImage(_ image: UIImage, with yolo: YOLO) -> ImageProcessingResult?
}

class ImageProcessingService: ImageProcessingServiceProtocol {
    func correctImageOrientation(_ image: UIImage) -> UIImage {
        let ciContext = CIContext()
        
        switch image.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: image)?.oriented(.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent)
            else { return image }
            return UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: image)?.oriented(.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent)
            else { return image }
            return UIImage(cgImage: cgImage)
        default:
            return image
        }
    }
    
    func processImage(_ image: UIImage, with yolo: YOLO) -> ImageProcessingResult? {
        let correctedImage = correctImageOrientation(image)
        let yoloResult = yolo(correctedImage)
        return ImageProcessingResult(
            originalImage: image,
            processedImage: correctedImage,
            yoloResult: yoloResult
        )
    }
}

// MARK: - ViewModel
@MainActor
class YOLOViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var processingResult: ImageProcessingResult?
    @Published var modelState: ModelLoadingState = .idle
    @Published var isProcessingImage = false
    @Published var errorMessage: String?
    
    private let modelDownloadService: ModelDownloadServiceProtocol
    private let imageProcessingService: ImageProcessingServiceProtocol
    private var currentModel: YOLOModel?
    
    init(
        modelDownloadService: ModelDownloadServiceProtocol = ModelDownloadService(),
        imageProcessingService: ImageProcessingServiceProtocol = ImageProcessingService()
    ) {
        self.modelDownloadService = modelDownloadService
        self.imageProcessingService = imageProcessingService
    }
    
    // MARK: - Model Management
    func loadModel(_ model: YOLOModel) async {
        modelState = .loading
        errorMessage = nil
        currentModel = model
        
        do {
            let yolo: YOLO
            
            if model.isRemote, let urlString = model.url {
                yolo = try await loadRemoteModel(name: model.name, url: urlString, task: model.task)
            } else {
                yolo = try loadLocalModel(name: model.name, task: model.task)
            }
            
            modelState = .loaded(yolo)
        } catch {
            modelState = .failed(error)
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }
    
    private func loadRemoteModel(name: String, url: String, task: YOLOTask) async throws -> YOLO {
        let fileName = "\(name).mlmodel"
        
        // Check if model is cached
        if let cachedURL = modelDownloadService.getCachedModelURL(fileName: fileName) {
            return try createYOLO(from: cachedURL.path, task: task)
        }
        
        // Download model
        let downloadedURL = try await modelDownloadService.downloadModel(from: url, fileName: fileName)
        return try createYOLO(from: downloadedURL.path, task: task)
    }
    
    private func loadLocalModel(name: String, task: YOLOTask) throws -> YOLO {
        return try createYOLO(from: name, task: task)
    }
    
    private func createYOLO(from path: String, task: YOLOTask) throws -> YOLO {
        switch task {
        case .detect:
            return YOLO(path, task: .detect)
        case .segment:
            return YOLO(path, task: .segment)
        case .classify:
            return YOLO(path, task: .classify)
        }
    }
    
    // MARK: - Image Processing
    func processSelectedImage() async {
        guard let image = selectedImage,
              case .loaded(let yolo) = modelState else {
            return
        }
        
        isProcessingImage = true
        errorMessage = nil
        
        // Process image in background task
        let result = await Task.detached { [imageProcessingService] in
            return imageProcessingService.processImage(image, with: yolo)
        }.value
        
        // Update UI on main actor
        processingResult = result
        isProcessingImage = false
        
        if result == nil {
            errorMessage = "Failed to process image"
        }
    }
    
    func updateSelectedImage(_ image: UIImage) async {
        selectedImage = image
        processingResult = nil
        await processSelectedImage()
    }
    
    func clearResults() {
        selectedImage = nil
        processingResult = nil
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    var isModelLoaded: Bool {
        if case .loaded = modelState { return true }
        return false
    }
    
    var isModelLoading: Bool {
        if case .loading = modelState { return true }
        return false
    }
    
    var displayImage: UIImage? {
        processingResult?.yoloResult.annotatedImage ?? selectedImage
    }
    
    var statusText: String {
        switch modelState {
        case .idle:
            return "No model selected"
        case .loading:
            return "Loading model..."
        case .loaded:
            if isProcessingImage {
                return "Processing image..."
            } else if selectedImage != nil {
                return "Image ready"
            } else {
                return "Model loaded - Select an image"
            }
        case .failed:
            return "Model failed to load"
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = YOLOViewModel()
    @State private var selectedItem: PhotosPickerItem?
    
    // Updated models - you need to extract the ZIP and provide direct .mlmodel URL
    private let availableModels = [
        YOLOModel(name: "yolo11n-seg", task: .segment),
        YOLOModel(
            name: "custom-fish-model",
            // TODO: Extract the ZIP file and upload the .mlmodel file directly
            // Then use: "https://github.com/DMelisena/yolo_try/releases/download/prerelease/best-e100-random-fishes.mlmodel"
            url: "https://github.com/DMelisena/yolo_try/releases/download/prerelease/best-e100-random-fishes.mlmodel.zip",
            task: .detect
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                StatusView(
                    statusText: viewModel.statusText,
                    errorMessage: viewModel.errorMessage
                )
                
                // Image Display Section
                ImageDisplayView(
                    image: viewModel.displayImage,
                    isProcessing: viewModel.isProcessingImage
                )
                
                Spacer()
                
                // Controls Section
                VStack(spacing: 15) {
                    // Model Selection
                    ModelSelectionView(
                        models: availableModels,
                        onModelSelected: { model in
                            Task {
                                await viewModel.loadModel(model)
                            }
                        }
                    )
                    
                    // Photo Picker
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("Select Photo")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isModelLoaded ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.isModelLoaded || viewModel.isProcessingImage)
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            await handleImageSelection(newItem)
                        }
                    }
                    
                    // Clear Button
                    if viewModel.selectedImage != nil {
                        Button("Clear") {
                            viewModel.clearResults()
                            selectedItem = nil
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("YOLO Detection")
        }
        .task {
            // Load default model on startup
            await viewModel.loadModel(availableModels[0])
        }
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        
        await viewModel.updateSelectedImage(image)
    }
}

struct StatusView: View {
    let statusText: String
    let errorMessage: String?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(statusText)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ImageDisplayView: View {
    let image: UIImage?
    let isProcessing: Bool
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .opacity(isProcessing ? 0.5 : 1.0)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                    .cornerRadius(10)
                    .overlay(
                        Text("No image selected")
                            .foregroundColor(.secondary)
                    )
            }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }
}

struct ModelSelectionView: View {
    let models: [YOLOModel]
    let onModelSelected: (YOLOModel) -> Void
    @State private var selectedModelIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Model:")
                .font(.headline)
            
            Picker("Model", selection: $selectedModelIndex) {
                ForEach(0..<models.count, id: \.self) { index in
                    Text(models[index].name)
                        .tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedModelIndex) { _, newIndex in
                onModelSelected(models[newIndex])
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
