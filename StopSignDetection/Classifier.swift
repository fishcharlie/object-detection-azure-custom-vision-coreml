//
//  Classifier.swift
//  StopSignDetection
//
//  Created by Charlie Fish on 11/14/21.
//

import Foundation
import CoreML
import Vision
import UIKit

class Classifier {
    static let shared: Classifier = Classifier()

    var isRunningClassification = false

    private lazy var model: VNCoreMLModel? = {
        guard let stopSignDetectionModel = try? StopSignDetectionModel(configuration: MLModelConfiguration()) else { return nil }
        return try? VNCoreMLModel(for: stopSignDetectionModel.model)
    }()

    private func classificationRequest(completionHandler: @escaping (VNRequest, Error?) -> Void) -> VNCoreMLRequest {
        guard let model = model else { fatalError("Model should exist") }

        let request = VNCoreMLRequest(model: model) { request, error in
            self.isRunningClassification = false
            completionHandler(request, error)
        }

        request.imageCropAndScaleOption = .scaleFit
        return request
    }

    func classify(image: UIImage, completionHandler: @escaping (VNRequest, Error?) -> Void) {
        isRunningClassification = true

        // Generate data to pass into classifier
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) else { return }
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }

        // Create request
        let request = classificationRequest(completionHandler: completionHandler)

        // Run classification
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }

    func classify(sampleBuffer: CMSampleBuffer, completionHandler: @escaping (VNRequest, Error?) -> Void) {
        isRunningClassification = true

        // Generate data to pass into classifier
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError("Error getting pixel buffer") }

        // Create request
        let request = classificationRequest(completionHandler: completionHandler)

        // Run classification
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
}

enum Label: String {
    case stopSign = "stop_sign"
    case oneWaySign = "oneway_sign"

    var color: UIColor {
        switch self {
        case .oneWaySign:
            return .blue
        case .stopSign:
            return .red
        }
    }
}
