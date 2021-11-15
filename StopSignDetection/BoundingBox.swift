//
//  BoundingBox.swift
//  StopSignDetection
//
//  Created by Charlie Fish on 11/14/21.
//

import UIKit
import Vision

class BoundingBoxLayer: CALayer {

    var label: String? {
        didSet {
            labelLayer.string = label
            setNeedsLayout()
        }
    }

    var color: UIColor = UIColor.clear {
        didSet {
            borderColor = color.cgColor
            labelLayer.backgroundColor = color.cgColor
        }
    }

    private var labelLayer = BoundingBoxLabelLayer()

    override init() {
        super.init()

        backgroundColor = UIColor.clear.cgColor
        borderColor = color.cgColor
        borderWidth = 3.0

        labelLayer.backgroundColor = color.cgColor
        labelLayer.foregroundColor = UIColor.black.cgColor
        labelLayer.contentsScale = UIScreen.main.scale
        labelLayer.font = CTFontCreateUIFontForLanguage(.label, 0.0, nil)
        labelLayer.fontSize = UIFont.systemFontSize
        labelLayer.alignmentMode = CATextLayerAlignmentMode.left
        labelLayer.padding = CGSize.init(width: 15.0, height: 6.0)

        addSublayer(labelLayer)
    }

    convenience init(frame: CGRect, label: Label, result: VNRecognizedObjectObservation) {
        self.init()

        self.frame = frame
        self.label = String(format: "%@ %.1f", label.rawValue, result.confidence * 100)
        self.color = label.color
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        let labelSize = labelLayer.preferredFrameSize()
        labelLayer.frame = CGRect.init(x: 0.0, y: -labelSize.height + self.borderWidth, width: labelSize.width, height: labelSize.height)
    }

}

class BoundingBoxLabelLayer: CATextLayer {
    public var padding = CGSize.zero {
        didSet {
            needsLayout()
        }
    }

    override func preferredFrameSize() -> CGSize {
        let textSize = super.preferredFrameSize()

        return CGSize.init(width: textSize.width + padding.width, height: textSize.height + padding.height)
    }

    override func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: padding.width / 2.0, y: padding.height / 2.0)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
}
