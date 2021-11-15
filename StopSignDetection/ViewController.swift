//
//  ViewController.swift
//  StopSignDetection
//
//  Created by Charlie Fish on 11/14/21.
//

import UIKit
import AVKit
import Vision
import CoreML

class ViewController: UIViewController {
    // - MARK: Properties

    private var captureSession: AVCaptureSession? = nil
    private var dataOutput: AVCaptureVideoDataOutput? = nil
    private var previewLayer: AVCaptureVideoPreviewLayer? = nil
    private var boundingBoxView: UIView? = nil

    // - MARK: IBOutlets

    @IBOutlet private var containerView: UIView!

    // - MARK: Utility Functions

    private func removeSubviewsFromView(_ view: UIView) {
        view.subviews.forEach { subview in
            subview.removeFromSuperview()
        }

        view.layer.sublayers = []
    }

    private func cleanup() {
        boundingBoxView?.layer.sublayers = []
        removeSubviewsFromView(containerView)
    }

    // - MARK: IBAction Functions

    @IBAction private func cameraButtonPressed() {
        cleanup()
        if captureSession != nil {
            stopCamera()
        } else {
            startCamera()
        }
    }

    @IBAction private func imagePictureButtonPressed() {
        cleanup()
        stopCamera()
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        self.present(imagePicker, animated: true)
    }

    // - MARK: UIViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        boundingBoxView = UIView()
        guard let boundingBoxView = boundingBoxView else { fatalError("boundingBoxView should exist here") }
        boundingBoxView.frame = containerView.frame
        self.view.addSubview(boundingBoxView)
    }

    // - MARK: Camera Functions

    private func startCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { fatalError("captureSession should exist here") }
        captureSession.sessionPreset = .photo
        captureSession.startRunning()

        // Add input for capture
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let captureInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(captureInput)

        // Add preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        guard let previewLayer = previewLayer else { fatalError("previewLayer should exist here") }
        containerView.layer.addSublayer(previewLayer)
        previewLayer.frame = containerView.bounds

        // Add output for capture
        dataOutput = AVCaptureVideoDataOutput()
        guard let dataOutput = dataOutput else { fatalError("dataOutput should exist here") }
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        if let dataOutput = dataOutput {
            captureSession?.removeOutput(dataOutput)
        }

        captureSession = nil
        dataOutput = nil
        previewLayer = nil
    }

    private var framesSinceLastClassification = 0
    var shouldClassifyCamera: Bool {
        if framesSinceLastClassification >= 10 {
            framesSinceLastClassification = 0
            return true
        } else {
            framesSinceLastClassification += 1
            return false
        }
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func denormalized(_ normalizedRect: CGRect, in imageView: UIImageView) -> CGRect {
        let imageSize = imageView.contentClippingRect.size
        let imageOrigin = imageView.contentClippingRect.origin

        let newOrigin = CGPoint(x: normalizedRect.minX * imageSize.width + imageOrigin.x, y: (1 - normalizedRect.maxY) * imageSize.height + imageOrigin.y)
        let newSize = CGSize(width: normalizedRect.width * imageSize.width, height: normalizedRect.height * imageSize.height)

        return CGRect(origin: newOrigin, size: newSize)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { fatalError("Can't get image") }

        Classifier.shared.classify(image: image, completionHandler: { request, error in
            DispatchQueue.main.async {
                // Create image view
                let imageView = UIImageView(image: image)
                imageView.frame = self.containerView.bounds
                imageView.contentMode = .scaleAspectFit
                self.containerView.addSubview(imageView)

                // Dismiss image picker
                picker.dismiss(animated: true)

                // Generate bounding boxes
                let results = request.results as? [VNRecognizedObjectObservation]
                results?.forEach { result in
                    guard let labelIdentifier = result.labels.sorted(by: { a, b in
                        return a.confidence > b.confidence
                    }).first?.identifier else { return }
                    guard let label = Label(rawValue: labelIdentifier) else { return }

                    let rect = self.denormalized(result.boundingBox, in: imageView)
                    let layer = BoundingBoxLayer()
                    layer.frame = rect
                    layer.label = String(format: "%@ %.1f", label.rawValue, result.confidence * 100)
                    layer.color = label.color

                    self.boundingBoxView?.layer.addSublayer(layer)
                }
            }
        })
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !shouldClassifyCamera {
            return
        }

        Classifier.shared.classify(sampleBuffer: sampleBuffer, completionHandler: { request, error in
            let results = request.results as? [VNRecognizedObjectObservation]

            DispatchQueue.main.async {
                if let boundingBoxView = self.boundingBoxView {
                    boundingBoxView.layer.sublayers = []
                }

                results?.forEach { result in
                    guard let previewLayer = self.previewLayer else { return }

                    let p1 = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(x: result.boundingBox.minX, y: result.boundingBox.minY))
                    let p2 = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(x: result.boundingBox.maxX, y: result.boundingBox.maxY))
                    let frame = CGRect.init(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))

                    guard let labelIdentifier = result.labels.sorted(by: { a, b in
                        return a.confidence > b.confidence
                    }).first?.identifier else { return }
                    guard let label = Label(rawValue: labelIdentifier) else { return }

                    let layer = BoundingBoxLayer()
                    layer.frame = frame
                    layer.label = String(format: "%@ %.1f", label.rawValue, result.confidence * 100)
                    layer.color = label.color

                    self.boundingBoxView?.layer.addSublayer(layer)
                }
            }
        })
    }
}
