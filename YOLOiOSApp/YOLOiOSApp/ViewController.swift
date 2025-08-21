// Modified ViewController.swift with image selection capabilities

import AudioToolbox
import AVFoundation
import CoreMedia
import CoreML
import Photos
import PhotosUI
import UIKit
import YOLO

// Add this enum for input modes
enum InputMode {
    case camera
    case image
}

class ViewController: UIViewController, YOLOViewDelegate {
    // Existing outlets...
    @IBOutlet var yoloView: YOLOView!
    @IBOutlet var View0: UIView!
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var labelName: UILabel!
    @IBOutlet var labelFPS: UILabel!
    @IBOutlet var labelVersion: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var focus: UIImageView!
    @IBOutlet var logoImage: UIImageView!

    // Add new UI elements for image selection
    private let inputModeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Camera", "Image"])
        control.selectedSegmentIndex = 0
        control.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        control.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.3)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let imageSelectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Image", for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    // MARK: - YOLOViewDelegate Methods
    
    // Handle detection results from YOLO model
    func yoloView(_ yoloView: YOLOView, didReceiveResult result: YOLOResult) {
        // Process detection results
        print("Received YOLO result")
        
        // Update UI with detection results if needed
        // For example, display bounding boxes, labels, etc.
    }
    
    // Handle errors from YOLO model
    func yoloView(_ yoloView: YOLOView, didFailWithError error: Error) {
        // Handle error
        print("YOLO processing failed with error: \(error.localizedDescription)")
    }
    
    // Handle when YOLO model is ready
    func yoloViewDidBecomeReady(_ yoloView: YOLOView) {
        // YOLO model is ready for processing
        print("YOLO model is ready for processing")
        
        // Start processing if needed
    }
    
    // Handle performance updates from YOLO model
    func yoloView(_ view: YOLOView, didUpdatePerformance fps: Double, inferenceTime: Double) {
        // Update performance metrics in UI
        DispatchQueue.main.async { [weak self] in
            self?.labelFPS.text = String(format: "%.1f FPS", fps)
        }
        print("YOLO performance: \(fps) FPS, inference time: \(inferenceTime) ms")
    }

    override func viewDidLoad() {
        // Existing implementation...
    }

    private func setupInputModeControl() {
        // Existing implementation...
    }

    private func setupImageSelectionUI() {
        // Existing implementation...
    }

    @objc private func inputModeChanged() {
        // Existing implementation...
    }

    private func switchInputMode(to mode: InputMode) {
        // Existing implementation...
    }

    private func updateFPSLabelVisibility() {
        // Existing implementation...
    }

    @objc private func selectImageButtonTapped() {
        // Existing implementation...
    }

    @objc private func processImageButtonTapped() {
        // Existing implementation...
    }

    private func presentImagePicker() {
        // Existing implementation...
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        // Existing implementation...
    }

    private func processImage(_ image: UIImage) {
        // Existing implementation...
    }

    private func displayImageResults(image: UIImage, result: YOLOResult) {
        // Existing implementation...
    }

    private func showAlert(title: String, message: String) {
        // Existing implementation...
    }

    override func viewDidLayoutSubviews() {
        // Existing implementation...
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // Existing implementation...
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // Existing implementation...
    }

    func processStaticImage(_ image: UIImage, completion: @escaping (Result<YOLOResult, Error>) -> Void) {
        // Existing implementation...
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func toPixelBuffer() -> CVPixelBuffer? {
        // Existing implementation...
        return nil
    }
}
