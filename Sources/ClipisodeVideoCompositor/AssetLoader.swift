import Foundation
import AVFoundation

public class AssetLoader : NSObject {
  let baseUrl: URL
  var assets: Dictionary<String, AVAsset> = [:];
  
  init(_ baseUrl: URL) {
    self.baseUrl = baseUrl
  }
  
  func load(key: String, filePath: String) -> AVAsset {
    var asset: AVAsset? = assets[key];
    
    var url: URL? = nil
    
    if filePath.contains("://") {
      url = URL(string: filePath)
    } else if filePath.starts(with: "/") {
      url = URL(fileURLWithPath: filePath)
    } else {
      url = URL(string: filePath, relativeTo: self.baseUrl)
    }

    if asset == nil, let u = url {
      asset = AVURLAsset(
        url: u,
        options: [AVURLAssetPreferPreciseDurationAndTimingKey:true]
      )
      assets[key] = asset;
    }

    let composition = AVMutableComposition()
    let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
    let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))

    if let _asset = asset {
      let sourceVideoTrack = _asset.tracks(withMediaType: .video).first
      let sourceAudioTrack = _asset.tracks(withMediaType: .audio).first
    
      do {
        if let _sourceVideoTrack = sourceVideoTrack {
          compositionVideoTrack?.preferredTransform = _sourceVideoTrack.preferredTransform
          try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: _asset.duration), of: _sourceVideoTrack, at: .zero)
        }
        if let _sourceAudioTrack = sourceAudioTrack {
          try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: _asset.duration), of: _sourceAudioTrack, at: .zero)
        }
      } catch {
        print("Error adding tracks")
      }
    }

    return composition;
  }
}
