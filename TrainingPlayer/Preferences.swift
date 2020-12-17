/////
////  Preferences.swift
///   Copyright © 2020 Dmitriy Borovikov. All rights reserved.
//

import Foundation

struct Preferences {
    @UserPreference("PlayListURL")
    static var playListURL: URL?
}
