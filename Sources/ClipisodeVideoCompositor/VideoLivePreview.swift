import SwiftUI
import AVKit

struct VideoLivePreview: View {
  var compositionManager: CompositionManager?
  var playerItem: AVPlayerItem?
  var player: AVPlayer?

  init(path: URL?) {
    if let url = path {
      compositionManager = CommandLineRender.loadCompositionManager(url)
      
      if let cm = compositionManager, let composition = cm.composition  {
        playerItem = AVPlayerItem(asset: composition)
        
        if let pi = playerItem {
          pi.videoComposition = cm.videoComposition

          if let tc = pi.customVideoCompositor as? ThemeCompositor {
            tc.compositionManager = cm
          }
          
          player = AVPlayer(playerItem: playerItem)
        }
      }
    }
  }
  
  var body: some View {
    VideoPlayer(player: player)
  }
}

struct VideoLivePreview_Previews: PreviewProvider {
  static var previews: some View {
    VideoLivePreview(path: nil)
  }
}
