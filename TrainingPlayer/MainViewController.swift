//
//  MainViewController.swift
//  TrainingPlayer
//
//  Created by Dmitriy Borovikov on 15.12.2020.
//

import Cocoa
import AVKit

class MainViewController: NSViewController {
    var playerView: AVPlayerView = AVPlayerView()
    @IBOutlet var toolbar: NSToolbar!
    @IBOutlet weak var textLabel: NSTextField!
    @IBOutlet weak var timeLabel: NSTextField!

    private var observerToken: Any?
    private let dateFormater: DateFormatter = {
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

        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.autoresizingMask = [.width, .height]
        view.addSubview(playerView)
        playerView.frame = view.bounds
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
            if observerToken != nil {
                playerView.player?.rate = 1
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: onEachSecond(_:))
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
        do {
            let playlistData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormater)
            playList = try decoder.decode(TrainingPlayerList.self, from: playlistData)
            saveBookmarkData(for: url)
            view.window?.title = playList!.title
        } catch {
            print(error)
        }
    }
    
    private func setupOverlay() {
        guard
            let contentOverlayView = playerView.contentOverlayView
        else { return }
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 30, weight: .regular)
        timeLabel.textColor = .white
        timeLabel.stringValue = " "
        timeLabel.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        timeLabel.isBordered = false

        textLabel.font = .systemFont(ofSize: 24, weight: .regular)
        textLabel.textColor = .white
        textLabel.stringValue = " "
        textLabel.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        textLabel.isBordered = false
        timeLabel.removeFromSuperview()
        textLabel.removeFromSuperview()
        contentOverlayView.addSubview(timeLabel)
        contentOverlayView.addSubview(textLabel)
        NSLayoutConstraint.activate([
            timeLabel.topAnchor.constraint(equalTo: contentOverlayView.topAnchor, constant: 15),
            timeLabel.leadingAnchor.constraint(equalTo: contentOverlayView.leadingAnchor, constant: 15),
            textLabel.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor, constant: -15),
            textLabel.leadingAnchor.constraint(equalTo: contentOverlayView.leadingAnchor, constant: 15),
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
        playerView.player?.preventsDisplaySleepDuringVideoPlayback = true
        let tolerance = CMTime(value: 1, timescale: 10)
        print(currentItem, item.beginTime, item.endTime, item.comment)
        observerToken = playerView.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: item.endTime.cmtime)], queue: nil) {
            let beginTime = item.beginTime.addingTimeInterval(1)
            self.playerView.player?.seek(to: beginTime.cmtime, toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
        self.playerView.player?.seek(to: item.beginTime.cmtime, toleranceBefore: tolerance, toleranceAfter: tolerance)
        self.playerView.player?.rate = 1
        textLabel.stringValue = "\(currentItem+1)/\(playList.items.count): \(item.comment)"
    
        secondsCount = item.playTime.seconds
        if secondsCount == 0 {
            secondsCount = Int(item.endTime.timeIntervalSince(item.beginTime))
        }
        secondsCount = Int(Float(secondsCount) * playList.playFactor)
        showSecondsCount()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: onEachSecond(_:))
    }
    
    private func onEachSecond(_ timer: Timer) {
        secondsCount -= 1
        showSecondsCount()
        guard secondsCount <= 0 else { return }
        if playerView.player?.rate ?? 0 == 0 {
            // Pause end
            timer.invalidate()
            self.timer = nil
        } else {
            // Clip end
            if let observerToken = observerToken {
                playerView.player?.removeTimeObserver(observerToken)
                self.observerToken = nil
            }
            if playList!.items[currentItem].pause {
                secondsCount = playList!.pauseTime
                playerView.player?.pause()
                return
            } else {
                timer.invalidate()
                self.timer = nil
            }
        }
        currentItem += 1
        guard currentItem < playList?.items.count ?? 0 else {
            textLabel.stringValue = ""
            timeLabel.stringValue = "End"
            playerView.player?.pause()
            playerView.player?.preventsDisplaySleepDuringVideoPlayback = false
            return
        }
        playVideo()    // Next video in playlist
    }
    
    private func showSecondsCount() {
        let seconds = String(format: "%d:%02d", secondsCount/60, secondsCount % 60)
        let state = playerView.player?.rate ?? 0 == 0 ? "Pause" : "Play"
        timeLabel.stringValue = "\(state): \(seconds)"
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
                saveBookmarkData(for: url)
            }
            return url
        } catch {
            print("Error resolving bookmark:", error)
            return nil
        }
    }

}
