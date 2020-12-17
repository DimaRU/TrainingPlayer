//
//  Date+extensions.swift
//  TrainingPlayer
//
//  Created by Dmitriy Borovikov on 17.12.2020.
//

import Foundation
import AVKit

extension Date {
    var cmtime: CMTime {
        CMTime(seconds: self.timeIntervalSinceReferenceDate, preferredTimescale: 10)
    }
    
    var seconds: Int {
        Int(self.timeIntervalSinceReferenceDate)
    }
}
