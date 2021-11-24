import CoreVideo
import CoreImage
import AVFoundation

struct FrameHandler {
  // This function takes a raw pixel buffer and uses the layer instruction to transform it into the correct orientation
  static func prepare(_ pixelBuffer: CVPixelBuffer, with instruction: AVVideoCompositionInstructionProtocol, on trackId: CMPersistentTrackID, at compositionTime: CMTime) -> CIImage {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    var sourceFrameImage = CIImage(cvPixelBuffer: pixelBuffer)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
  
    if let compositionInstruction = instruction as? AVVideoCompositionInstruction {
      if let li = compositionInstruction.layerInstructions.first(where: { $0.trackID == trackId }) {
        var startTransform: CGAffineTransform = .identity
        
        if li.getTransformRamp(for: compositionTime, start: &startTransform, end: nil, timeRange: nil) {
          if !startTransform.isIdentity {
            var rotatedTransform = startTransform

            if rotatedTransform.tx == sourceFrameImage.extent.height, rotatedTransform.ty == 0 {
              rotatedTransform = rotatedTransform
                .rotated(by: -.pi)
                .translatedBy(x: -sourceFrameImage.extent.width, y: -sourceFrameImage.extent.height)
            }
            
            sourceFrameImage = sourceFrameImage.transformed(by: rotatedTransform)
          }
        }
      }
    }
    
    return sourceFrameImage
  }
}
