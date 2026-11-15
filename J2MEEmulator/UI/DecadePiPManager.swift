//
//  DecadePiPManager.swift
//  J2MEEmulator
//
//  Decade Picture-in-Picture (PiP) Engine for iOS.
//  Enables a persistent, interactive floating window over SpringBoard (Home Screen)
//  and all other apps while J2ME runs in the background.
//

import UIKit
import AVKit
import AVFoundation
import CoreMedia
import VideoToolbox

final class DecadePiPManager: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    static let shared = DecadePiPManager()

    private var pipController: AVPictureInPictureController?
    let displayLayer = AVSampleBufferDisplayLayer()
    private(set) var isPiPActive = false

    private var frameTimer: DispatchSourceTimer?
    private var pixelBufferPool: CVPixelBufferPool?
    private var isPlaying = true

    override init() {
        super.init()
        setupPiPLayer()
    }

    private func setupPiPLayer() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[DecadePiP] AVPictureInPictureController is not supported on this device")
            return
        }

        displayLayer.videoGravity = .resizeAspect
        displayLayer.isOpaque = true

        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )

        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipController = controller
        print("[DecadePiP] PiP controller initialized successfully")
    }

    func attachDisplayLayer(to parentView: UIView) {
        if displayLayer.superlayer == nil {
            displayLayer.frame = CGRect(x: 0, y: 0, width: 240, height: 320)
            parentView.layer.addSublayer(displayLayer)
        }
    }

    func togglePiP() {
        if isPiPActive {
            stopPiP()
        } else {
            startPiP()
        }
    }

    func startPiP() {
        guard let controller = pipController else {
            print("[DecadePiP] PiP controller is nil")
            return
        }

        // Ensure audio session is playback
        DecadeBackgroundKeeper.shared.startKeepalive()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Feed an initial frame so PiP has content immediately
            self.pushCurrentFrame()
            self.startFrameStreaming()

            if controller.isPictureInPicturePossible {
                controller.startPictureInPicture()
                print("[DecadePiP] Started Picture-in-Picture")
            } else {
                print("[DecadePiP] PiP not possible yet, scheduled start...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    controller.startPictureInPicture()
                }
            }
        }
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
        stopFrameStreaming()
    }

    // MARK: - Frame Streaming to AVSampleBufferDisplayLayer

    private func startFrameStreaming() {
        stopFrameStreaming()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(100)) // 10 fps stream for battery efficiency in PiP
        timer.setEventHandler { [weak self] in
            self?.pushCurrentFrame()
        }
        timer.resume()
        self.frameTimer = timer
    }

    private func stopFrameStreaming() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    func pushCurrentFrame() {
        guard let image = captureCurrentGameFrame() else { return }
        feedImageToDisplayLayer(image)
    }

    private func captureCurrentGameFrame() -> UIImage? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.keyWindow else {
            return nil
        }
        // If GameViewController is active, capture its emulator view
        if let root = window.rootViewController {
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            if let gameVC = top as? GameViewController {
                return gameVC.captureScreenshot()
            }
        }
        return nil
    }

    private func feedImageToDisplayLayer(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pxData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pxData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        if let ctx = context {
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 10),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDesc
        )

        guard let format = formatDesc else { return }

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard let sample = sampleBuffer else { return }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }

        displayLayer.enqueue(sample)
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
        print("[DecadePiP] PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[DecadePiP] PiP did start - now floating outside app")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isPiPActive = false
        stopFrameStreaming()
        print("[DecadePiP] Failed to start PiP: \(error.localizedDescription)")
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[DecadePiP] PiP will stop")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
        stopFrameStreaming()
        print("[DecadePiP] PiP did stop")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    // MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        isPlaying = playing
        if playing {
            startFrameStreaming()
        } else {
            stopFrameStreaming()
        }
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackLikelyToKeepUp(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return true
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
