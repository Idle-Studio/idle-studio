import AVFoundation

/// Manages looping ambient audio per era. Audio files must be present in `Bundle.main`
/// (e.g. `ambient_stone_age.mp3` in the app target's Resources folder).
/// All methods silently no-op if the file is missing or sound is disabled in Settings.
@MainActor public final class AudioService {
    public static let shared = AudioService()

    private var ambientPlayer: AVAudioPlayer?
    private var currentAsset: String?

    private init() {
        // .playback ignores the Ring/Silent switch — game music should always play
        // when the user has sound enabled in the app, regardless of system mute.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Start looping the named ambient track. Does nothing if already playing the same track.
    public func playAmbient(asset: String) {
        // Treat "never set" as enabled (default true), only silence when explicitly disabled.
        let explicitlyDisabled = UserDefaults.standard.object(forKey: "sound_enabled") != nil
                              && !UserDefaults.standard.bool(forKey: "sound_enabled")
        guard !explicitlyDisabled else { return }
        guard asset != currentAsset else { return }
        let url = Bundle.main.url(forResource: asset, withExtension: "mp3")
               ?? Bundle.main.url(forResource: asset, withExtension: "wav")
        guard let url else { return }
        currentAsset = asset   // only update after confirming the file exists
        ambientPlayer?.stop()
        ambientPlayer = try? AVAudioPlayer(contentsOf: url)
        ambientPlayer?.numberOfLoops = -1
        ambientPlayer?.volume = 0.4
        ambientPlayer?.prepareToPlay()
        ambientPlayer?.play()
    }

    /// Stop the current ambient track and clear state so the next `playAmbient` call
    /// will start fresh (useful when sound is toggled off).
    public func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
        currentAsset = nil
    }
}
