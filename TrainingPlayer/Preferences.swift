/////
////  Preferences.swift
///   Copyright © 2020 Dmitriy Borovikov. All rights reserved.
//

import Foundation

struct Preferences {
    @UserPreference("PlayListBookmark")
    static var playListBookmark: Data?
}
