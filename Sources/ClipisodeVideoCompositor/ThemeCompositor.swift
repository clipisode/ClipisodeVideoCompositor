import Foundation
import CoreImage
import CoreMedia
import CoreGraphics
import AVFoundation

public class ThemeCompositor: NSObject, AVVideoCompositing {
  public var compositionManager: CompositionManager? = nil

  private var frameQueue = OperationQueue()

  public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    if compositionManager?.manifest == nil {
      request.finish(with: AVError(.videoCompositorFailed))
    } else {
      frameQueue.addOperation {
        RenderFrameOperation(request, self.compositionManager).start()
      }
    }
  }

  public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    // we use renderContext from the AVAsynchronousVideoCompositionRequest passed to renderIntoContext
  }

  public func cancelAllPendingVideoCompositionRequests() {
    frameQueue.cancelAllOperations()
  }

  public var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
    String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
  ]

  public var sourcePixelBufferAttributes: [String : Any]? = [
    String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
  ]
}
