//
//  RectDrawerView.swift
//  DigitRecognizer
//
//  Created by Artur on 23.04.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import UIKit

class RectDrawerView: UIView {
    
    public var rectsToLabels = [CGRect: Int]() {
        didSet {
            self.subviews.forEach { $0.removeFromSuperview() }
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        UIColor.red.setStroke()
        
        for rect in rectsToLabels.keys {
            let rectPath = UIBezierPath(rect: rect)
            rectPath.lineWidth = 2
            rectPath.stroke()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let rect = rectsToLabels.keys.filter( { $0.contains(touch.location(in: self)) }).first else {
                return
            }
            let label = rectsToLabels[rect]!
            let labelView = UILabel(frame: CGRect(x: rect.minX, y: rect.minY - 32, width: 20, height: 32))
            labelView.backgroundColor = .white
            labelView.font = UIFont.systemFont(ofSize: 18)
            labelView.text = "\(label)"
            labelView.textAlignment = .center
            addSubview(labelView)
        }
    }

}

extension CGRect: Hashable {
    public var hashValue: Int {
        return Int(minX + 10000*minY + 100000*width + 1000000*height)
    }
}
