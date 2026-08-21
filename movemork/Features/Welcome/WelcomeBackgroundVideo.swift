//
//  WelcomeBackgroundVideo.swift
//  movemork
//
//  Welcome-only looping background. `AVPlayerLayer` rather than `VideoPlayer` so there is no
//  transport UI, no gesture handling and no chrome to suppress.
//

import AVFoundation
import SwiftUI

struct WelcomeBackgroundVideo: UIViewRepresentable {
    let isPlaying: Bool

    func makeUIView(context: Context) -> WelcomeLoopingPlayerView {
        let view = WelcomeLoopingPlayerView()
        if let url = Bundle.main.url(forResource: "movemark-welcome-master", withExtension: "mp4") {
            view.configure(url: url)
        }
        // Missing asset is survivable: the poster underneath is already on screen.
        view.setPlaying(isPlaying)
        return view
    }

    func updateUIView(_ uiView: WelcomeLoopingPlayerView, context: Context) {
        uiView.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: WelcomeLoopingPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class WelcomeLoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVQueuePlayer?
    /// Held strongly on purpose — `AVPlayerLooper` stops looping if it is allowed to deallocate.
    private var looper: AVPlayerLooper?

    func configure(url: URL) {
        guard player == nil else { return }

        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        // The master carries no audio track, but an explicit mute keeps the app out of the
        // audio session entirely — a background loop must never duck someone's music.
        queuePlayer.actionAtItemEnd = .none

        looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill

        player = queuePlayer
    }

    func setPlaying(_ shouldPlay: Bool) {
        guard let player else { return }
        if shouldPlay {
            player.play()
        } else {
            player.pause()
        }
    }

    func stop() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
        playerLayer.player = nil
    }
}
