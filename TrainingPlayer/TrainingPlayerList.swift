//
//  TrainingPlayerList.swift
//  TrainingPlayer
//
//  Created by Dmitriy Borovikov on 16.12.2020.
//

import Foundation

struct TrainingPlayerList: Decodable {
    struct Item: Codable {
        let track: Int
        let beginTime: Date
        let endTime: Date
        let playTime: Date
        let pauseTime: Int
        let comment: String
    }
    let videoPaths: [String]
    let items: [Item]
}
