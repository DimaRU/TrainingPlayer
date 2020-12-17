//
//  TrainingPlayerList.swift
//  TrainingPlayer
//
//  Created by Dmitriy Borovikov on 16.12.2020.
//

import Foundation

struct TrainingPlayerList: Decodable {
    struct Item: Codable {
        let trackNumber: Int
        let beginTime: Date
        let endTime: Date
        let playTime: Date
        let pauseTime: Date
    }
    let videoPaths: [String]
    let items: [Item]
}
