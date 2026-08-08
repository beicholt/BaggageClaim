import AVFoundation

/// The prototype's four blips, synthesised rather than shipped as files.
///
/// Real sound is a polish-stage job. Until then these carry the timing
/// information the game actually depends on — the pitch of a pop rises with
/// the flow multiplier, which is how you hear that you are on a run.
final class Audio {
    static let shared = Audio()

    enum Cue { case pick, pop, returnBag, no }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var started = false
    var muted = false

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: mixer, format: format)
            players.append(p)
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            for p in players { p.play() }
        } catch {
            started = false            // audio is a nicety, never a blocker
        }
    }

    func play(_ cue: Cue, step: Int = 0) {
        guard !muted else { return }
        startIfNeeded()
        guard started else { return }

        let freqs: [Double]
        switch cue {
        case .pop:       freqs = [523.25 + Double(step) * 62, 784 + Double(step) * 62]
        case .pick:      freqs = [330]
        case .returnBag: freqs = [262]
        case .no:        freqs = [110]
        }
        let peak: Float = cue == .pop ? 0.16 : 0.07
        let square = cue == .no

        for (i, f) in freqs.enumerated() {
            guard let buffer = tone(frequency: f, peak: peak, square: square) else { continue }
            let player = players[next % players.count]
            next += 1
            let when = AVAudioTime(sampleTime: AVAudioFramePosition(Double(i) * 0.06 * 44_100),
                                   atRate: 44_100)
            player.scheduleBuffer(buffer, at: player.lastRenderTime.flatMap {
                player.playerTime(forNodeTime: $0).map {
                    AVAudioTime(sampleTime: $0.sampleTime + when.sampleTime, atRate: 44_100)
                }
            }, options: [], completionHandler: nil)
        }
    }

    private func tone(frequency: Double, peak: Float, square: Bool) -> AVAudioPCMBuffer? {
        let duration = 0.24
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        let step = 2 * Double.pi * frequency / format.sampleRate
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            // Fast attack, exponential decay — a blip, not a note.
            let env = Float(exp(-t * 18)) * (t < 0.005 ? Float(t / 0.005) : 1)
            let raw = sin(Double(i) * step)
            let s = square ? (raw >= 0 ? 1.0 : -1.0) : raw
            data[i] = Float(s) * env * peak
        }
        return buffer
    }
}
