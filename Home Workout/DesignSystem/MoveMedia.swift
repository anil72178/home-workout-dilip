//
//  MoveMedia.swift
//  Home Workout
//
//  Every clip sits on a "stage": a rounded card painted in the clip's own
//  studio colour so the video edges disappear into the card.
//

import SwiftUI
import AVFoundation
import AVKit

/// A muted, looping exercise clip.
struct LoopingVideo: UIViewRepresentable {
    let url: URL
    var isPlaying: Bool = true
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.configure(url: url, gravity: gravity)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.currentURL != url { view.configure(url: url, gravity: gravity) }
        view.shouldPlay = isPlaying
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player?.pause()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private(set) var currentURL: URL?
        /// Desired state; the clip only actually plays while on screen.
        var shouldPlay = true { didSet { syncPlayback() } }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            syncPlayback()
        }

        private func syncPlayback() {
            if shouldPlay && window != nil { player?.play() } else { player?.pause() }
        }

        func configure(url: URL, gravity: AVLayerVideoGravity) {
            currentURL = url
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = true
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            playerLayer.player = queue
            playerLayer.videoGravity = gravity
            backgroundColor = .clear
            syncPlayback()
        }
    }
}

/// Fills any frame with a clip: a blurred, enlarged copy of the clip's own
/// still sits behind it, so floor shadows and wall tones match exactly and
/// the fitted video melts into its surroundings whatever its aspect ratio.
struct StageMedia: View {
    let exercise: Exercise
    var live: Bool = false
    var isPlaying: Bool = true
    /// Space kept clear around the clip (e.g. under overlaid controls).
    var inset = EdgeInsets()
    @State private var liveBackdrop: UIImage?

    var body: some View {
        let still = exercise.thumbnail
        let aspect = still.map { $0.size.width / max($0.size.height, 1) } ?? 1
        ZStack {
            exercise.stageColor
            if let backdrop = (live ? liveBackdrop : nil) ?? exercise.backdrop {
                Image(uiImage: backdrop)
                    .resizable()
                    .blur(radius: 12, opaque: true)
            }
            Group {
                if live, let url = exercise.videoURL {
                    LoopingVideo(url: url, isPlaying: isPlaying)
                        .id(exercise.id)
                } else if let still {
                    Image(uiImage: still).resizable()
                } else {
                    Image(systemName: "figure.strengthtraining.functional")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .featheredEdges(live ? 0.16 : 0.1)
            .padding(inset)
        }
        .clipped()
        .task(id: live ? exercise.id : nil) {
            guard live else { return }
            let image = await exercise.videoBackdrop()
            withAnimation(.easeOut(duration: 0.25)) { liveBackdrop = image }
        }
    }
}

/// Square stage for tiles and cards.
struct MoveStage: View {
    let exercise: Exercise
    var live: Bool = false
    var isPlaying: Bool = true
    var radius: CGFloat = Metric.tileRadius

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { StageMedia(exercise: exercise, live: live, isPlaying: isPlaying) }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}

/// Free-size cover (fills whatever frame it's given).
struct MoveCover: View {
    let exercise: Exercise
    var live: Bool = false

    var body: some View {
        StageMedia(exercise: exercise, live: live)
    }
}

extension View {
    /// Fades the outer few percent of a clip so its edges melt into the stage colour.
    func featheredEdges(_ amount: CGFloat = 0.1) -> some View {
        mask {
            let h = LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: amount),
                                           .init(color: .black, location: 1 - amount), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
            let v = LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: amount),
                                           .init(color: .black, location: 1 - amount), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
            h.mask(v)
        }
    }
}
