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
    
    private var playerList: TrainingPlayerList?
    private var currentItem: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidAppear() {
        setupOverlay()
    }
    
    @IBAction func startButtonPress(_ sender: NSToolbarItem) {
        guard let playerList = playerList else { return }
        let item = playerList.items[currentItem]
        playVideo(playerList.videoPaths[item.trackNumber], item: item)
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

    private func playVideo(_ file: String, item: TrainingPlayerList.Item) {
        let videoURL = URL(fileURLWithPath: file)
        let oneSecond = CMTime(value: 1, timescale: 10)
        playerView.player = AVPlayer(url: videoURL)
        observerToken = playerView.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: item.endTime.cmtime)], queue: nil) {
            self.playerView.player?.seek(to: item.beginTime.cmtime, toleranceBefore: oneSecond, toleranceAfter: oneSecond)
        }
        self.playerView.player?.seek(to: item.beginTime.cmtime, toleranceBefore: oneSecond, toleranceAfter: oneSecond) { _ in
            self.playerView.player?.rate = 1
        }
        
    }
}
