import Vision

struct FaceDetection {
  
  
  static func observe(_ image: CGImage) -> [VNFaceObservation] {
    let imageRequestHandler = VNImageRequestHandler(cgImage: image, orientation: .down, options: [:])
    var results: [VNFaceObservation]? = nil
    
    let group = DispatchGroup()
    group.enter()
    
    lazy var rectangleDetectionRequest: VNDetectFaceLandmarksRequest = {
      let rectDetectRequest = VNDetectFaceLandmarksRequest { request, error in
        results = request.results as? [VNFaceObservation]
        
        group.leave()
      }
      
      return rectDetectRequest
    }()

    do {
      try imageRequestHandler.perform([rectangleDetectionRequest])
    } catch {
      print("ERROR")
    }
    
    group.wait()
    
    return results ?? []
  }
}
