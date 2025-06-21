//
//  ScreenColorService.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 5/29/25.
//

import Foundation
import CoreGraphics
import CoreImage
import ScreenCaptureKit
import AVFoundation

class ScreenColorService: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let ciContext: CIContext
    
    // Closure to be called with the new average color, or nil on error/stop.
    var onNewAverageColor: ((r: UInt8, g: UInt8, b: UInt8)?) -> Void = { _ in }
    
    // Configuration for the capture performance and quality.
    private let settings: AppSettings
    
    
    init(settings: AppSettings) {
        self.settings = settings
        self.ciContext = CIContext(options: [CIContextOption.priorityRequestLow: true])
        super.init()
        print("[ScreenColorService] Initialized.")
    }
    
    deinit {
        stopMonitoring()
        print("[ScreenColorService] Deinitialized.")
    }
    
    @MainActor
    func startMonitoring(for display: SCDisplay) {
        guard stream == nil else {
            print("[ScreenColorService] Monitoring is already active.")
            return
        }
        
        print("[ScreenColorService] Attempting to start screen monitoring for display \(display.displayID)...")
        
        Task {
            do {
                // The content filter now uses the specific display passed to the function.
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                let config = SCStreamConfiguration()
                config.width = settings.captureWidth
                config.height = settings.captureHeight
                config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(settings.captureFPS))
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.capturesAudio = false
                config.showsCursor = false
                config.queueDepth = 3 
                
                self.stream = SCStream(filter: filter, configuration: config, delegate: self)
                
                // Add the stream output with a background queue for processing.
                try self.stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
                
                try await self.stream?.startCapture()
                
                print("[ScreenColorService] ScreenCaptureKit stream started successfully for display \(display.displayID).")
                
            } catch {
                print("[ScreenColorService] Error starting ScreenCaptureKit stream: \(error.localizedDescription)")
                self.onNewAverageColor(nil)
                self.stream = nil
            }
        }
    }
    
    func stopMonitoring() {
        guard let stream = self.stream else { return }
        
        print("[ScreenColorService] Attempting to stop ScreenCaptureKit stream.")
        stream.stopCapture { [weak self] error in
            if let error = error {
                print("[ScreenColorService] Error stopping stream: \(error.localizedDescription)")
            } else {
                print("[ScreenColorService] Stream stopped successfully.")
            }
            // Ensure state is cleaned up on the main thread if needed by UI.
            DispatchQueue.main.async {
                self?.stream = nil
                self?.onNewAverageColor(nil)
            }
        }
    }
    
    // MARK: - SCStreamOutput Delegate
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        // Ensure we have a valid screen sample buffer
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Use the highly efficient "CIAreaAverage" filter to get the average color.
        let filterName = "CIAreaAverage"
        guard let filter = CIFilter(name: filterName) else {
            print("[ScreenColorService] Could not create \(filterName) filter.")
            self.onNewAverageColor(nil)
            return
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else {
            self.onNewAverageColor(nil)
            return
        }
        
        // Render the 1x1 output image to a bitmap to extract RGBA values.
        var bitmap = [UInt8](repeating: 0, count: 4)
        
        self.ciContext.render(outputImage,
                              toBitmap: &bitmap,
                              rowBytes: 4,
                              bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                              format: .RGBA8,
                              colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        
        let r = bitmap[0]
        let g = bitmap[1]
        let b = bitmap[2]
        
        // Send the new color to the manager.
        self.onNewAverageColor((r, g, b))
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[ScreenColorService] Stream stopped with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.stream = nil
            self.onNewAverageColor(nil)
        }
    }
}
