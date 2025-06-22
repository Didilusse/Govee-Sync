//
//  AudioCaptureService.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import Accelerate

/// A service to capture and analyze system audio output in real-time.
class AudioCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    
    private var stream: SCStream?
    
    var onNewAudioLevel: ((Float) -> Void)?
    
    private var filteredLevel: Float = 0.0
    private let filterFactor: Float = 0.4

    // This function is now async, which is a cleaner and safer concurrency pattern.
    func startMonitoring() async {
        // If a stream is already running, we don't need to do anything.
        guard stream == nil else {
            print("[AudioCaptureService] Monitoring is already active.")
            return
        }

        print("[AudioCaptureService] Attempting to start audio monitoring...")

        do {
            // Get the list of available displays and windows.
            let content = try await SCShareableContent.current
            
            // We need to anchor the audio stream to a display.
            guard let display = content.displays.first else {
                print("[AudioCaptureService] No display found to anchor the audio stream.")
                return
            }
            
            // Create a filter for the main display, which is required to create a stream.
            let filter = SCContentFilter(display: display, excludingWindows: [])

            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            
            // Explicitly disable video to prevent errors and improve performance.
            config.width = 1
            config.height = 1
            config.pixelFormat = 0 // kCVPixelFormatType_Invalid
            
            // ** THIS IS THE FIX **
            // We create a new local stream constant and configure it completely
            // before assigning it to the class property. This avoids race conditions.
            let newStream = try SCStream(filter: filter, configuration: config, delegate: self)
            
            // Add ourself as the audio output handler.
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
            
            // Await the start of the capture. This will trigger the permission prompt if needed.
            try await newStream.startCapture()
            
            // Only after the stream has successfully started do we assign it to our instance property.
            self.stream = newStream
            
            print("[AudioCaptureService] Audio stream started successfully.")
            
        } catch {
            print("[AudioCaptureService] FAILED to start audio stream: \(error.localizedDescription)")
            self.stream = nil
        }
    }

    func stopMonitoring() {
        guard let stream = stream else { return }
        print("[AudioCaptureService] Stopping audio stream.")
        stream.stopCapture { [weak self] error in
            if let error = error {
                print("[AudioCaptureService] Error stopping stream: \(error.localizedDescription)")
            }
            // Ensure the stream property is nilled out after stopping.
            self?.stream = nil
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        
        guard let level = calculateRMS(from: sampleBuffer) else { return }
        
        // Apply a smoothing filter for a less "jumpy" visual effect.
        filteredLevel = (filterFactor * level) + ((1.0 - filterFactor) * filteredLevel)
        
        DispatchQueue.main.async {
            self.onNewAudioLevel?(self.filteredLevel)
        }
    }
    
    private func calculateRMS(from sampleBuffer: CMSampleBuffer) -> Float? {
        var bufferListSize: Int = 0
        var blockBuffer: CMBlockBuffer?

        do {
            try CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: &bufferListSize,
                bufferListOut: nil,
                bufferListSize: 0,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &blockBuffer)
        } catch {
            print("[AudioCaptureService] Error getting audio buffer size: \(error.localizedDescription)")
            return nil
        }
        
        let audioBufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferListSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { audioBufferListPointer.deallocate() }

        let audioBufferList = audioBufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)

        do {
            try CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: audioBufferList,
                bufferListSize: bufferListSize,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &blockBuffer)
        } catch {
            print("[AudioCaptureService] Error getting audio buffer list: \(error.localizedDescription)")
            return nil
        }

        guard let firstBuffer = UnsafeMutableAudioBufferListPointer(audioBufferList).first else { return nil }

        let frameCount = Int(firstBuffer.mDataByteSize) / MemoryLayout<Float>.size
        guard let samples = firstBuffer.mData?.bindMemory(to: Float.self, capacity: frameCount) else { return nil }

        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
        
        let amplifier: Float = 8.0
        return min(max(rms * amplifier, 0.0), 1.0)
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[AudioCaptureService] Stream stopped with error: \(error.localizedDescription)")
        self.stream = nil
    }
}
