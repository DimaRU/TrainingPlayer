//
//  MainViewController.swift
//  TrainingPlayer
//
//  Created by Dmitriy Borovikov on 15.12.2020.
//

import Cocoa
import AVKit

let videoPathString1 = "/Users/dmitry/Movies/Реабилитация, ЛФК плечевого сустава 1.mp4"
let videoPathString2 = "/Users/dmitry/Movies/Реабилитация, ЛФК плечевого сустава 2.mp4"

class MainViewController: NSViewController {
    @IBOutlet weak var playerView: AVPlayerView!
    @IBOutlet var toolbar: NSToolbar!

    private var observerToken: Any?
    private var textLabel: NSTextField = NSTextField()
    let dateFormater: DateFormatter = {
        let formater = DateFormatter()
        formater.locale = .current
        formater.dateFormat = "m:ss"
        formater.defaultDate = Date(timeIntervalSinceReferenceDate: 0)
        formater.timeZone = TimeZone(abbreviation: "UTC")
        return formater
    }()
    
    private var playList: TrainingPlayerList?
    private var currentItem: Int = 0
    private var currentTrack: Int?
    private var timer: Timer?
    private var secondsCount: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidAppear() {
        setupOverlay()
    }
    
    @IBAction func openMenuAction(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["json"]
        panel.title = "Choose training playlist"
        let response = panel.runModal()
        guard
            response == .OK,
            let url = panel.url
        else { return }
        loadPlayList(url: url)

        currentItem = 0
        playVideo()
    }
    
    @IBAction func startButtonPress(_ sender: Any?) {
        if playList == nil, let url = restoreFileAccess() {
            loadPlayList(url: url)
        }
        currentItem = 0
        playVideo()
    }
    
    @IBAction func pauseButtonPress(_ sender: Any) {
        if timer != nil {
            playerView.player?.pause()
            timer?.invalidate()
        } else {
            playerView.player?.rate = 1
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.onEachSecond()
            }
        }
    }
    
    override func viewWillAppear() {
        view.window?.toolbar = toolbar
    }

    private func loadPlayList(url: URL) {
        if !url.startAccessingSecurityScopedResource() {
            print("startAccessingSecurityScopedResource returned false.")
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        guard
            let playlistData = try? Data(contentsOf: url)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormater)
        playList = try? decoder.decode(TrainingPlayerList.self, from: playlistData)
        saveBookmarkData(for: url)

        currentItem = 0
        playVideo()
    }
    
    private func setupOverlay() {
        guard
            let contentOverlayView = playerView.contentOverlayView
        else { return }
        
        textLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.stringValue = " "
        textLabel.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        textLabel.isBordered = false
        contentOverlayView.addSubview(textLabel)
        NSLayoutConstraint.activate([
            textLabel.widthAnchor.constraint(equalToConstant: 200),
            textLabel.topAnchor.constraint(equalTo: contentOverlayView.topAnchor, constant: 15),
            textLabel.leadingAnchor.constraint(equalTo: contentOverlayView.leadingAnchor, constant: 15)
        ])
    }

    private func playVideo() {
        guard
            let playList = playList,
            currentItem < playList.items.count
        else { return }
        let item = playList.items[currentItem]
        if currentTrack != item.track {
            currentTrack = item.track
            let filePath = playList.videoPaths[item.track]
            let videoURL = URL(fileURLWithPath: filePath)
            playerView.player = AVPlayer(url: videoURL)
        }
        let oneSecond = CMTime(value: 1, timescale: 10)
        observerToken = playerView.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: item.endTime.cmtime)], queue: nil) {
            self.playerView.player?.seek(to: item.beginTime.cmtime, toleranceBefore: oneSecond, toleranceAfter: oneSecond)
        }
        self.playerView.player?.seek(to: item.beginTime.cmtime, toleranceBefore: oneSecond, toleranceAfter: oneSecond) { _ in
            self.playerView.player?.rate = 1
        }
        secondsCount = item.playTime.seconds
        showSecondsCount()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.onEachSecond()
        }
    }
    
    private func onEachSecond() {
        secondsCount -= 1
        showSecondsCount()
        guard secondsCount <= 0 else { return }
        if playerView.player?.rate ?? 0 == 0 {
            timer?.invalidate()
            timer = nil
            currentItem += 1
            playVideo()    // Next video in playlist
        } else {
            secondsCount = playList!.items[currentItem].pauseTime.seconds
            playerView.player?.pause()
        }
    }
    
    private func showSecondsCount() {
        let seconds = String(format: "%d:%02d", secondsCount/60, secondsCount % 60)
        let state = playerView.player?.rate ?? 0 == 0 ? "Pause" : "Play"
        textLabel.stringValue = "\(state) ex \(currentItem+1)/\(playList!.items.count) : \(seconds)"
    }
    
    private func saveBookmarkData(for file: URL) {
        do {
            let bookmarkData = try file.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            Preferences.playListBookmark = bookmarkData
        } catch {
            print("Failed to save bookmark data for \(file)", error)
        }
    }
    
    private func restoreFileAccess() -> URL? {
        guard let bookmarkData = Preferences.playListBookmark else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                // bookmarks could become stale as the OS changes
                print("Bookmark is stale, need to save a new one... ")
                saveBookmarkData(for: url)
            }
            return url
        } catch {
            print("Error resolving bookmark:", error)
            return nil
        }
    }

}
