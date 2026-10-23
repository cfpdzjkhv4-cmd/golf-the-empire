import AVFoundation

/// Plays sounds by manifest id, through the asset library. Uses the "ambient" audio session,
/// so the game mixes with the player's own music and respects the silent switch.
@MainActor
final class SoundBoard {
    static let shared = SoundBoard()

    var isEnabled = true {
        didSet { if !isEnabled { stopAmbience() } }
    }

    private var players: [String: [AVAudioPlayer]] = [:]
    private var ambience: [AVAudioPlayer] = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// A one shot sound effect, e.g. "sfx_cup".
    func play(_ id: String, volume: Float = 1, after delay: TimeInterval = 0) {
        guard isEnabled else { return }
        if delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                self.play(id, volume: volume)
            }
            return
        }
        let player = freePlayer(id)
        player?.volume = volume
        player?.currentTime = 0
        player?.play()
    }

    /// Loops ambience beds quietly underneath everything, replacing any already playing.
    func playAmbience(_ ids: [String], volume: Float = 0.35) {
        stopAmbience()
        guard isEnabled else { return }
        for id in ids {
            guard let url = AssetLibrary.shared.soundURL(id), let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.numberOfLoops = -1
            p.volume = 0
            p.play()
            p.setVolume(volume, fadeDuration: 1.5)
            ambience.append(p)
        }
    }

    func stopAmbience() {
        for p in ambience { p.stop() }
        ambience.removeAll()
    }

    /// Reuses a player that has finished, so rapid repeats overlap instead of cutting off.
    private func freePlayer(_ id: String) -> AVAudioPlayer? {
        if let idle = players[id]?.first(where: { !$0.isPlaying }) { return idle }
        guard (players[id]?.count ?? 0) < 4, let url = AssetLibrary.shared.soundURL(id),
              let p = try? AVAudioPlayer(contentsOf: url) else { return players[id]?.first }
        p.prepareToPlay()
        players[id, default: []].append(p)
        return p
    }
}
