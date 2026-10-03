//
//  Coach.swift
//  Home Workout
//
//  Voice cues, countdown beeps and haptics during a session. Audio mixes
//  with (and briefly ducks) whatever music the user is already playing.
//

import AVFoundation
import UIKit

@MainActor
final class Coach {
    var voiceOn = true
    var soundsOn = true

    private let synth = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let tonePlayer = AVAudioPlayerNode()
    private var tickBuffer: AVAudioPCMBuffer?
    private var goBuffer: AVAudioPCMBuffer?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        tickBuffer = Self.tone(frequency: 880, duration: 0.09, format: format)
        goBuffer = Self.tone(frequency: 1320, duration: 0.22, format: format)
        engine.attach(tonePlayer)
        engine.connect(tonePlayer, to: engine.mainMixerNode, format: format)
        try? engine.start()
        light.prepare()
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        tonePlayer.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Cues

    func say(_ text: String) {
        guard voiceOn else { return }
        synth.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        synth.speak(utterance)
    }

    /// Short tick for the last seconds of a countdown.
    func tick() {
        light.impactOccurred(intensity: 0.6)
        play(tickBuffer)
    }

    /// Longer tone when a move starts.
    func go() {
        notify.notificationOccurred(.success)
        play(goBuffer)
    }

    func celebrate() {
        notify.notificationOccurred(.success)
        say("Workout complete. Brilliant job!")
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard soundsOn, let buffer, engine.isRunning else { return }
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !tonePlayer.isPlaying { tonePlayer.play() }
    }

    private static func tone(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            let envelope = min(1, t * 80) * min(1, (duration - t) * 40)   // soft attack/release, no clicks
            data[i] = Float(sin(2 * .pi * frequency * t) * 0.35 * envelope)
        }
        return buffer
    }
}
