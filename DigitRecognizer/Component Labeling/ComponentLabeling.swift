//
//  ComponentLabeling.swift
//  DigitRecognizer
//
//  Created by Artur on 23.04.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import CoreGraphics

class ComponentLabeling {
    
    static func extractComponents(imageData: [UInt8], height: Int, width: Int) -> [CGRect] {
        var currentLabel = 0
        var labelsUnion = UnionFind(capacity: height * width)
        
        var labels = [[Int]].init(repeating: [Int](repeating: -1, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                if imageData[y*width + x] != 0 { // Not background pixel
                    if x == 0 { // Left no pixel
                        if y == 0 { // Top no pixel
                            labelsUnion.addSetWith(currentLabel)
                            labels[y][x] = currentLabel
                            currentLabel += 1
                        } else if y > 0 { //Top pixel
                            if imageData[(y - 1)*width + x] != 0 { //Top Label
                                labels[y][x] = labels[y - 1][x]
                            } else { //Top no Label
                                labelsUnion.addSetWith(currentLabel)
                                labels[y][x] = currentLabel
                                currentLabel += 1
                            }
                        }
                    } else { //Left pixel
                        if y == 0 { //Top no pixel
                            if imageData[y*width + x - 1] != 0 { //Left Label
                                labels[y][x] = labels[y][x - 1]
                            } else { //Left no Label
                                labelsUnion.addSetWith(currentLabel)
                                labels[y][x] = currentLabel
                                currentLabel += 1
                            }
                        } else if y > 0 { //Top pixel
                            if imageData[y * width + x - 1] != 0 { //Left Label
                                if imageData[(y - 1)*width + x] != 0 { //Top Label
                                    labelsUnion.unionSetsContaining(labels[y - 1][x], and: labels[y][x - 1])
                                    
                                    labels[y][x] = labels[y - 1][x]
                                } else { //Top no Label
                                    labels[y][x] = labels[y][x - 1]
                                }
                            } else { //Left no Label
                                if imageData[(y - 1)*width + x] != 0 { //Top Label
                                    labels[y][x] = labels[y - 1][x]
                                } else { //Top no Label
                                    labelsUnion.addSetWith(currentLabel)
                                    labels[y][x] = currentLabel
                                    currentLabel += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        // Second pass
        for y in 0..<height {
            for x in 0..<width {
                
                if imageData[y*width + x] != 0 {
                    labels[y][x] = labelsUnion.setByIndex(labels[y][x])
                }
            }
        }

        var minMaxXYLabelDict = Dictionary<Int, (minX: Int, maxX: Int, minY: Int, maxY: Int)>()
        
        for y in 0..<height {
            for x in 0..<width {
                guard imageData[y*width + x] != 0 else {
                    continue
                }
                    if (minMaxXYLabelDict[labels[y][x]] == nil) {
                        minMaxXYLabelDict[labels[y][x]] = (minX: width, maxX: 0, minY: height, maxY: 0)
                    }
                    var value = minMaxXYLabelDict[labels[y][x]]!
                    
                    value.minX = min(value.minX, x)
                    value.maxX = max(value.maxX, x)
                    value.minY = min(value.minY, y)
                    value.maxY = max(value.maxY, y)
                    
                    minMaxXYLabelDict[labels[y][x]] = value
            }
        }
        
        let rects: [CGRect] = Array(minMaxXYLabelDict.values.flatMap({
            let rect = CGRect(x: $0.minX, y: $0.minY, width: $0.maxX - $0.minX, height: $0.maxY - $0.minY)
            
            if (rect.width / rect.height < 1.2 && rect.height*rect.width > 8 && rect.minX != 0 && rect.minY != 0 && rect.maxX != CGFloat(width) && rect.maxY != CGFloat(height)) {
                return rect
            } else {
                return nil
            }
        }))
        
        var mergedRects = [CGRect]()
        for rect in rects {
            var intersects = false
            for (j, mRect) in mergedRects.enumerated() {
                // Check if rects intersects with allowed margin of 2
                if (mRect.insetBy(dx: -1, dy: -2).intersects(rect)) {
                    mergedRects[j] = mRect.union(mRect)
                    intersects = true
                }
            }
            if (!intersects) {
                mergedRects.append(rect)
            }
        }
        
        return mergedRects.filter { $0.height * $0.width > 256 }
    }
}
