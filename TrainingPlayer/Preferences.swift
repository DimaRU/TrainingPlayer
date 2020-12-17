/////
////  Preferences.swift
///   Copyright © 2020 Dmitriy Borovikov. All rights reserved.
//

import Foundation

struct Preference {
    @UserPreference("PlayListFile")
    static var playListFile: CGFloat?
}
