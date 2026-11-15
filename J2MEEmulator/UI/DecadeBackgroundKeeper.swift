//
//  DecadeBackgroundKeeper.swift
//  J2MEEmulator
//
//  Decade Background Keepalive Engine.
//  Keeps J2ME threads and network sockets alive indefinitely in background / screen lock.
//

import UIKit
import AVFoundation

final class DecadeBackgroundKeeper {
    static let shared = DecadeBackgroundKeeper()

    private var audioPlayer: AVAudioPlayer?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private(set) var isTreoActive: Bool = false

    private init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func setTreoActive(_ active: Bool) {
        isTreoActive = active
        if active {
            startKeepalive()
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            stopKeepalive()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func startKeepalive() {
        startSilentAudio()
        beginBackgroundTask()
    }

    func stopKeepalive() {
        audioPlayer?.stop()
        audioPlayer = nil
        endBackgroundTask()
    }

    @objc private func handleAppDidEnterBackground() {
        if isTreoActive {
            startKeepalive()
        }
    }

    @objc private func handleAppWillEnterForeground() {
        endBackgroundTask()
    }

    private func startSilentAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)

            if audioPlayer == nil {
                let silentWavData = createSilentWavData()
                audioPlayer = try AVAudioPlayer(data: silentWavData)
                audioPlayer?.numberOfLoops = -1 // Infinite loop
                audioPlayer?.volume = 0.01 // Zero audible sound, but recognized by audio engine
                audioPlayer?.prepareToPlay()
            }
            audioPlayer?.play()
        } catch {
            print("[DecadeBackgroundKeeper] Audio setup error: \(error)")
        }
    }

    private func beginBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        bgTask = UIApplication.shared.beginBackgroundTask(withName: "DecadeKeepaliveTask") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }

    /// Synthesizes a valid 1-second 8kHz mono 16-bit PCM silent WAV in memory
    private func createSilentWavData() -> Data {
        let sampleRate: Int32 = 8000
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let dataSize: Int32 = sampleRate * Int32(channels) * Int32(bitsPerSample / 8) // 1 second
        let totalSize: Int32 = 36 + dataSize

        var data = Data()
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(withUnsafeBytes(of: totalSize.littleEndian) { Data($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // "fmt " chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let fmtSize: Int32 = 16
        data.append(withUnsafeBytes(of: fmtSize.littleEndian) { Data($0) })
        let pcmFormat: Int16 = 1
        data.append(withUnsafeBytes(of: pcmFormat.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate: Int32 = sampleRate * Int32(channels) * Int32(bitsPerSample / 8)
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign: Int16 = channels * (bitsPerSample / 8)
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // "data" chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // 1 second of zeroes (silence)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
