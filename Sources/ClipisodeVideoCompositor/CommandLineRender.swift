import Foundation
import AVFoundation

public struct CommandLineRender {
  public init() { }

  public static func isCommandLineRun() -> Bool {
    return CommandLine.arguments.contains { argument in
      argument == "--background"
    }
  }
  
  public static func dataDir() -> URL? {
    if isCommandLineRun() {
      let directoryPath = "/Users/max/Desktop/RenderTestFiles/TC1/" //argv[2];
      var isDir: ObjCBool = false
        
      if (FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDir)) {
        if (isDir.boolValue) {
          return URL(fileURLWithPath: directoryPath, isDirectory: true)
        }
      }
    }
    
    return nil
  }
  
  public static func loadCompositionManager(_ url: URL) -> CompositionManager? {
    do {
      let data = try Data(contentsOf: url.appendingPathComponent("composition.json"))
      let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
      
      if let jsonResult = jsonResult as? [String:AnyObject] {
        return CompositionManager(manifest: jsonResult, baseUrl: url)
      }
    } catch {
      print("error: \(error)")
    }
    
    return nil
  }
  
  public func run(url: URL) async {
    var start = Date()
    
    if let compositionManager = CommandLineRender.loadCompositionManager(url) {
      let outUrl = url.appendingPathComponent("out.mp4")
      
      if FileManager.default.fileExists(atPath: outUrl.path) {
        do {
          try FileManager.default.removeItem(at: outUrl)
        } catch {
          print("Error deleting out.mp4")
        }
      }
      
      if let composition = compositionManager.composition, let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) {
        exportSession.outputURL = url.appendingPathComponent("out.mp4")
        
        if FileManager.default.fileExists(atPath: outUrl.path) {
          do {
            try FileManager.default.removeItem(at: exportSession.outputURL!)
          } catch { print("Failed to delete") }
        }
        
        exportSession.outputFileType = .mp4
        
        exportSession.videoComposition = compositionManager.videoComposition
        
        if exportSession.customVideoCompositor != nil {
          if let tc = exportSession.customVideoCompositor as? ThemeCompositor {
            tc.compositionManager = compositionManager
          }
        }

//        let progressCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _timer in
//          print("Progress: \(exportSession.progress)")
//
//          if exportSession.progress == 1.0 {
//            _timer.invalidate()
//          }
//        }

        start = Date()
        await exportSession.export()
        let end = Date()
        print("Elapsed: \(end.timeIntervalSince(start))")
        

        // The timer may have been invalidated by its own progress check
//        if progressCheckTimer.isValid {
//          progressCheckTimer.invalidate()
//        }

        if exportSession.status == .failed {
          if let err = exportSession.error {
            print(err.localizedDescription)
          } else {
            print("Failed for unknown reason!")
          }
          
          exit(EXIT_FAILURE)
        } else {
          print("Success!")
        }
      }
    }
  }
}
