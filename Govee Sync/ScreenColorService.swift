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
    private var currentDisplay: SCDisplay?
    
    
    var onNewAverageColor: ((r: UInt8, g: UInt8, b: UInt8)?) -> Void = { _ in }
    
    
    private let captureFPS: Int32 = 10
    
    private let captureWidth = 64
    private let captureHeight = 36
    
    
    override init() {
        self.ciContext = CIContext(options: [CIContextOption.priorityRequestLow: true])
        super.init()
        print("[ScreenColorService] Initialized.")
    }
    
    @MainActor
    func startMonitoring() {
        guard stream == nil else {
            print("[ScreenColorService] Monitoring is already active.")
            return
        }
        print("[ScreenColorService] Attempting to start screen monitoring with ScreenCaptureKit...")
        
        Task {
            do {
                let content = try await SCShareableContent.current
                
                
                self.currentDisplay = content.displays.first { $0.displayID == CGMainDisplayID() && $0.width > 0 && $0.height > 0 }
                
                guard let displayToCapture = self.currentDisplay else {
                    print("[ScreenColorService] No suitable display found to capture (e.g., main display not active).")
                    self.onNewAverageColor(nil)
                    return
                }
                
                print("[ScreenColorService] Target display: ID \(displayToCapture.displayID), Size: \(displayToCapture.width)x\(displayToCapture.height)")
                
                
                let filter = SCContentFilter(display: displayToCapture, excludingWindows: [])
                
                let config = SCStreamConfiguration()
                
                config.width = self.captureWidth
                config.height = self.captureHeight
                config.minimumFrameInterval = CMTime(value: 1, timescale: self.captureFPS)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.capturesAudio = false
                config.showsCursor = false
                config.queueDepth = 3
                
                
                self.stream = SCStream(filter: filter, configuration: config, delegate: self)
                
                
                try self.stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
                
                
                try await self.stream?.startCapture()
                
                print("[ScreenColorService] ScreenCaptureKit stream started successfully.")
                
            } catch {
                print("[ScreenColorService] Error starting ScreenCaptureKit stream: \(error.localizedDescription)")
                self.onNewAverageColor(nil)
                self.stream = nil
            }
        }
    }
    
    func stopMonitoring() {
        DispatchQueue.main.async {
            guard self.stream != nil else { return }
            print("[ScreenColorService] Attempting to stop ScreenCaptureKit stream.")
            self.stream?.stopCapture { [weak self] error in
                if let error = error {
                    print("[ScreenColorService] Error stopping stream: \(error.localizedDescription)")
                } else {
                    print("[ScreenColorService] Stream stopped successfully.")
                }
                self?.stream = nil
                self?.onNewAverageColor(nil)
            }
        }
    }
    
    // MARK: - SCStreamOutput Delegate
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            // print("[ScreenColorService] Could not get CVPixelBuffer from sample buffer.")
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let filterName = "CIAreaAverage"
        guard let filter = CIFilter(name: filterName) else {
            print("[ScreenColorService] Could not create \(filterName) filter.")
            self.onNewAverageColor(nil)
            return
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else {
            // print("[ScreenColorService] Failed to get outputImage from \(filterName) filter")
            self.onNewAverageColor(nil)
            return
        }
        
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
        
        self.onNewAverageColor((r, g, b))
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("[ScreenColorService] Stream stopped with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.stream = nil
            self.onNewAverageColor(nil)
            
        }
    }
    
    
    
    
    deinit {
        stopMonitoring()
        print("[ScreenColorService] Deinitialized.")
    }
}
