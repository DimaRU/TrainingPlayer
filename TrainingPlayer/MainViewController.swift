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
    }
    
    @IBAction func startButtonPress(_ sender: Any?) {
        currentItem = 0
        playVideo()
    }
    
    @IBAction func pauseButtonPress(_ sender: Any) {
        guard let observerToken = observerToken else { return }
        playerView.player?.removeTimeObserver(observerToken)
        self.observerToken = nil
        playerView.player?.pause()
    }
    
    override func viewWillAppear() {
        view.window?.toolbar = toolbar
    }

    private func loadPlayList(url: URL) {
        guard
            let playlistData = try? Data(contentsOf: url)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormater)
        playList = try? decoder.decode(TrainingPlayerList.self, from: playlistData)
        Preferences.playListURL = url
        startButtonPress(nil)
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
            textLabel.widthAnchor.constraint(equalToConstant: 100),
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
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.secondsCount -= 1
            self.showSecondsCount()
            guard self.secondsCount > 0 else { return }
            if self.playerView.player?.rate ?? 0 == 0 {
                self.currentItem += 1
                self.timer?.invalidate()
                self.playVideo()    // Next video in playlist
            } else {
                self.secondsCount = item.pauseTime.seconds
                self.playerView.player?.pause()
            }
        }
    }
    
    private func showSecondsCount() {
        let secondString = String(format: "%d:%2d", secondsCount/60, secondsCount % 60)
        textLabel.stringValue = secondString
    }
}
