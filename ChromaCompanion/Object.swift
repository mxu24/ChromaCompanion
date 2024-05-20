//
//  Object.swift
//  ChromaCompanion
//
//  Created by Kathy Yao on 5/20/24.
//

import Foundation
import CoreGraphics

struct DetectedObject {
    var frame: CGRect
    var id: Int
    var label: String
    var confidence: Float
}
