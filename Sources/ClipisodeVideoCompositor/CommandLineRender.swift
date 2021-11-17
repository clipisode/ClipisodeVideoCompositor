import Foundation
import AVFoundation

public struct CommandLineRender {
  static func isCommandLineRun() -> Bool {
    let argv = ProcessInfo.processInfo.arguments

    return argv.count == 3 && argv[1] == "--background"
  }
  
  static func dataDir() -> URL? {
    let argv = ProcessInfo.processInfo.arguments
    
    if (argv.count == 3) {
      let directoryPath = "/var/folders/g3/f07kz8_56sq56rhh08l13_h00000gn/T/tmp-64812yhxObLOnwf3/" //argv[2];
      var isDir: ObjCBool = false
        
      if (FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDir)) {
        if (isDir.boolValue) {
          return URL(string: directoryPath)
        }
      }
    }
    
    return nil
  }
  
  static func loadCompositionManager(_ url: URL) -> CompositionManager? {
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: "\(url.absoluteString)/composition.json"))
      let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
      
      if let jsonResult = jsonResult as? Dictionary<String, AnyObject> {
        return CompositionManager(manifest: jsonResult)
      }
    } catch {
      print("error: \(error)")
    }
    
    return nil
  }
  
  func run(url: URL) async {
    if let compositionManager = CommandLineRender.loadCompositionManager(url) {
      if let composition = compositionManager.composition, let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) {
        exportSession.outputURL = url.appendingPathComponent("out.mp4")
        exportSession.outputFileType = .mp4
        
        exportSession.videoComposition = compositionManager.videoComposition
        
        if exportSession.customVideoCompositor != nil {
          if let tc = exportSession.customVideoCompositor as? ThemeCompositor {
            tc.compositionManager = compositionManager
          }
        }

        let progressCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _timer in
          print("Progress: \(exportSession.progress)")

          if exportSession.progress == 1.0 {
            _timer.invalidate()
          }
        }

        await exportSession.export()

        // The timer may have been invalidated by its own progress check
        if progressCheckTimer.isValid {
          progressCheckTimer.invalidate()
        }

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
