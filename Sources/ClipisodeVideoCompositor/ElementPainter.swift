import Foundation
import CoreGraphics
import CoreText
import CoreMedia
import AVFoundation
import CoreImage
import CoreFoundation
import AppKit
import Vision

public typealias Element = Dictionary<String, Any>
public typealias Props = Dictionary<String, Any>

public class ElementPainter {
  // We know we're working with kCVPixelFormatType_32BGRA
  private let COLOR_COMPONENT_COUNT: size_t = 4
  
  private let coordinateTransform: CGAffineTransform

  let context: CGContext
  let manager: CompositionManager
  let files: Dictionary<String, String>
  
  public init(context: CGContext, height: Int, manager: CompositionManager, files: Dictionary<String, String>) {
    self.context = context
    self.manager = manager
    self.files = files
    
    coordinateTransform = CGAffineTransform.identity
      .translatedBy(x: 0, y: CGFloat(height))
      .scaledBy(x: 1, y: -1)
  }
  
  public func drawBackground() {
    context.setFillColor(.black)

    let bounds = CGRect(
      x: 0,
      y: 0,
      width: context.width,
      height: context.height
    )

    context.fill(bounds)
  }
  
  public func drawElement(type: String, element: Element, props: Props, at: CMTime, compositionRequest: AVAsynchronousVideoCompositionRequest? = nil) {
    switch type {
    case "image":
      drawImage(props: props)
    case "rect":
      drawRectangle(props: props)
    case "gradient":
      drawGradient(props: props)
    case "video":
      if let request = compositionRequest, let elementName = element["name"] as? String {
        drawVideo(elementName: elementName, props: props, at: at, request: request)
      }
    case "frame":
      if let elementName = element["name"] as? String {
        drawFrame(elementName: elementName, props: props)
      }
    case "text":
      drawText(props: props)
    default:
      print("Element type not supported.")
    }
  }
  
  private func drawVideo(elementName: String, props: Props, at compositionTime: CMTime, request: AVAsynchronousVideoCompositionRequest) {
    let alpha = props["alpha"] as? Double ?? 1.0

    if let trackId = manager.videoTrackId(elementName: elementName)  {
      let requestedFrame = request.sourceFrame(byTrackID: trackId)

      if let sourceFrame = requestedFrame {
        let sourceFrameImage = FrameHandler.prepare(sourceFrame, with: request.videoCompositionInstruction, on: trackId, at: compositionTime)
        let coreImageContext = CIContext(cgContext: context, options: nil)
        
        if let sourceFrame = coreImageContext.createCGImage(sourceFrameImage, from: sourceFrameImage.extent) {
          let bounds = rectFromProps(props)

          let drawImageProps = DrawImageProps(resizeMode: .contain, bounds: bounds, alpha: alpha)
          
          draw(sourceFrame, with: drawImageProps)
        }
      }
    }
  }
  
  private func calculateRectForResizeMode(sourceWidth: Double, sourceHeight: Double, resizeMode: String, x: Double, y: Double ,width: Double, height: Double) -> CGRect {
    var finalX = x
    var finalY = y
    var finalWidth = width
    var finalHeight = height
    
    // ADJUST FOR HEIGHT
    
    if sourceHeight < height {
      finalHeight = height
      finalWidth = finalHeight * (sourceWidth / sourceHeight)
    }
    
    // ADJUST FOR WIDTH (if necessary)
    
    if finalWidth < sourceWidth {
      finalWidth = width
      finalHeight = finalWidth * (sourceHeight / sourceWidth)
    }
    
    if finalWidth > width {
      finalX = x - ((finalWidth - width) / 2)
    }
    
    if finalHeight > height {
      finalY = y - ((finalHeight - height) / 2)
    }
    
    return CGRect(
      origin: CGPoint(x: x, y: y),
      size: CGSize(width: width, height: height)
    )
  }
  
  
  enum ImageResizeMode {
    case cover
    case contain
    case fill
  }

  struct DrawImageProps {
    var resizeMode: ImageResizeMode = .contain
    var bounds: CGRect
    var alpha: Double = 1.0
  }
  
  private func draw(_ image: CGImage, with props: DrawImageProps) {
    let finalRect = calculateRectForResizeMode(
      sourceWidth: Double(image.width),
      sourceHeight: Double(image.height),
      resizeMode: "contain",
      x: props.bounds.minX, y: props.bounds.minY, width: props.bounds.width, height: props.bounds.height
    )
    
    context.saveGState()

    context.clip(to: props.bounds)
    context.setAlpha(CGFloat(props.alpha))
    context.draw(image, in: finalRect)

    context.restoreGState()
  }
  
  private func drawFrame(elementName: String, props: Props) {
    if let frameImage = manager.frame(elementName: elementName) {
      let alpha = props["alpha"] as? Double ?? 1.0
      let rect = rectFromProps(props)
      
      let drawImageProps = DrawImageProps(resizeMode: .contain, bounds: rect, alpha: alpha)
      
      draw(frameImage, with: drawImageProps)
    } else {
      print("No frame")
    }
  }
  
  // https://stackoverflow.com/a/45815004
  private func createCGImage(from: CIImage) -> CGImage? {
    let context = CIContext(options: nil)

    return context.createCGImage(from, from: from.extent)
  }
  
  private func imageByKey(_ key: String) -> CGImage? {
    return self.manager.image(key) {
      var image: CGImage? = nil

      if let filePath = self.files[key] {
        let imageUrl = URL(fileURLWithPath: filePath, relativeTo: self.manager.baseUrl)
        
        if let ciImage = CIImage(contentsOf: imageUrl) {
          image = createCGImage(from: ciImage)
        } else {
          print("CIImage not loaded")
        }
      } else {
        print("File path not found for image")
      }

      return image
    }
  }
  
  private func drawImage(props: Props) {
    let alpha = props["alpha"] as? Double ?? 1.0
    let imageKey = props["imageKey"] as? String
    let rect = rectFromProps(props)
    
    var image: CGImage? = nil
    
    if let imageKey = props["imageKey"] as? String {
      image = imageByKey(imageKey)
    }
    
    if (image == nil) {
      print("Image not found for key: '\(imageKey ?? "{nil}")'");
    } else {
      context.saveGState()
      
      context.setAlpha(CGFloat(alpha))
      context.draw(image!, in: rect)
      
      context.restoreGState()
    }
  }
  
  private func drawRectangle(props: Props) {
    let color = props["color"] as? String ?? "#000000"
    let alpha = props["alpha"] as? Double ?? 1.0
    let cornerRadius = props["cornerRadius"] as? Double ?? 0
    let strokeColor = props["strokeColor"] as? String ?? "#000000"
    let strokeAlpha = props["strokeAlpha"] as? Double ?? 1.0
    let strokeWidth = props["strokeWidth"] as? Double ?? 0.0
    
    let rect = rectFromProps(props)
    
    let floatRadius = CGFloat(cornerRadius)

    let rectBezierPath = CGPath(roundedRect: rect, cornerWidth: floatRadius, cornerHeight: floatRadius, transform: nil)
    let fillColor = ColorHelper.getColorObjectFromHexString(color: color, alpha: alpha)
    
    context.setFillColor(fillColor)
    context.addPath(rectBezierPath)
    context.fillPath()
    
    if (strokeWidth > 0) {
      let uiStrokeWidth = CGFloat(strokeWidth)
      
      let strokeRect = CGRect(
        x: rect.origin.x - uiStrokeWidth / 2,
        y: rect.origin.y - uiStrokeWidth / 2,
        width: rect.size.width + uiStrokeWidth,
        height: rect.size.height + uiStrokeWidth
      )
      
      let strokeRectBezierPath = CGPath(
        roundedRect: strokeRect,
        cornerWidth: floatRadius + uiStrokeWidth / 2,
        cornerHeight: floatRadius + uiStrokeWidth / 2,
        transform: nil
      )
      
      let strokeColor = ColorHelper.getColorObjectFromHexString(color: strokeColor, alpha: strokeAlpha)
      
      context.setStrokeColor(strokeColor)
      context.setLineWidth(uiStrokeWidth)
      context.addPath(strokeRectBezierPath)
      context.strokePath()
    }
  }
  
  private func drawGradient(props: Props) {
    let alpha = props["alpha"] as? Double ?? 1.0
    let rVal = props["rVal"] as? Double ?? 52.0
    let gVal = props["gVal"] as? Double ?? 152.0
    let bVal = props["bVal"] as? Double ?? 219.0
    
    // TODO: 👆 alpha is the only supported prop right now to support fading in/out.
    // This needs to be updated to support colors, locations, and path.
    
    var gradient: CGGradient
    var colorSpace: CGColorSpace
    
    let numberOfLocations = 3
    
    let colorOne = CGColor(red: CGFloat(rVal)/255.0, green: CGFloat(gVal)/255.0, blue: CGFloat(bVal)/255.0, alpha: 0)
    let colorTwo = CGColor(red: CGFloat(rVal)/255.0, green: CGFloat(gVal)/255.0, blue: CGFloat(bVal)/255.0, alpha: 0.8)
    let colorThree = CGColor(red: CGFloat(rVal)/255.0, green: CGFloat(gVal)/255.0, blue: CGFloat(bVal)/255.0, alpha: 1)

    
    let scc = colorOne.components!
    let mcc = colorTwo.components!
    let ecc = colorThree.components!
    
    let locations: [CGFloat] = [0.0, 0.45, 1.0];
    let components: [CGFloat] = [ scc[0], scc[1], scc[2], scc[3],
                                  mcc[0], mcc[1], mcc[2], mcc[3],
                                  ecc[0], ecc[1], ecc[2], ecc[3] ];
    
    let height: CGFloat = 210.0
    
    colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    gradient = CGGradient(
      colorSpace: colorSpace,
      colorComponents: components,
      locations: locations,
      count: numberOfLocations
    )!

    let myStartPoint: CGPoint = CGPoint(x: 0.0, y: 1280.0 - height).applying(coordinateTransform)
    let myEndPoint: CGPoint = CGPoint(x: 0.0, y: 1280.0).applying(coordinateTransform)

    context.saveGState()
    context.clip(to:
      CGRect(
        origin: CGPoint(x: 0, y: 1280 - height),
        size: CGSize(width: 720, height: 1280)
      ).applying(coordinateTransform)
    )
    context.setAlpha(CGFloat(alpha))
    
    context.drawLinearGradient(gradient, start: myStartPoint, end: myEndPoint, options: .init(rawValue: 0))
    
    context.restoreGState()
  }
  
  private func drawText(props: Props) {
    let value = props["value"] as? String ?? ""
    let alpha = props["alpha"] as? Double ?? 1.0
    let fontName = props["fontName"] as? String ?? "Open Sans"
    let fontSize = props["fontSize"] as? Double ?? 44
    let color = props["color"] as? String ?? "#FFFFFF"
    let textAlign = props["textAlign"] as? String ?? "left"
    var lineHeight = props["lineHeight"] as? Double ?? fontSize * 1.4
    let originY = props["originY"] as? String ?? "top"
    let x = props["x"] as? Double ?? 0.0
    var y = props["y"] as? Double ?? 0.0
    let width = props["width"] as? Double ?? 0.0
    let height = props["height"] as? Double ?? 0.0
    let shadowColor = props["shadowColor"] as? String
    let shadowAlpha = props["shadowAlpha"] as? Double ?? 1.0
    let shadowBlurRadius = props["shadowBlurRadius"] as? Double
    
    // TODO: Can we check the validity of fontName?
    
    let descriptor = CTFontDescriptorCreateWithNameAndSize(fontName as CFString, CGFloat(fontSize))
    let font = CTFontCreateWithFontDescriptor(descriptor, 0.0, nil)
    let foregroundColor = ColorHelper.getColorObjectFromHexString(color: color, alpha: alpha)
    
    var alignment: CTTextAlignment
    
    switch textAlign {
    case "center":
      alignment = .center
    case "right":
      alignment = .right
    case "justified":
      alignment = .justified
    case "natural":
      alignment = .natural
    default:
      alignment = .left
    }
    
    var paragraphStyle: CTParagraphStyle? = nil
    
    withUnsafePointer(to: &lineHeight, { lineHeightPointer in
      withUnsafePointer(to: &alignment) { alignmentPointer in
        let styleSettings: [CTParagraphStyleSetting] = [
          CTParagraphStyleSetting(spec: .minimumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: lineHeightPointer),
          CTParagraphStyleSetting(spec: .maximumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: lineHeightPointer),
          CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignmentPointer)
        ]
        
        paragraphStyle = CTParagraphStyleCreate(styleSettings, styleSettings.count)
      }
    })

    var attributes: [NSAttributedString.Key : Any] = [
      .font: font,
      .foregroundColor: foregroundColor,
    ]
    
    if let _shadowColor = shadowColor, let _shadowBlurRadius = shadowBlurRadius {
      let shadowNSColor = NSColor(cgColor: ColorHelper.getColorObjectFromHexString(color: _shadowColor, alpha: shadowAlpha))
      let shadow = NSShadow()
      shadow.shadowColor = shadowNSColor
      shadow.shadowBlurRadius = _shadowBlurRadius
      
      attributes[.shadow] = shadow
    }

    if let _paragraphStyle = paragraphStyle {
      attributes[.paragraphStyle] = _paragraphStyle
    }
    
    let attrString = NSAttributedString(string: value, attributes: attributes)
    let frameSetter = CTFramesetterCreateWithAttributedString(attrString);

    let currentRange = CFRangeMake(0, 0)
    
    // vertical align center or bottom?
    let frameConstraints = CGSize(width: width, height: height)
    let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, currentRange, nil, frameConstraints, nil);
    
    if originY == "bottom" {
      y = y - Double(frameSize.height)
    } else if originY == "center" {
      y = y - Double(frameSize.height / 2)
    }
    
    let framePath = CGMutablePath()
    framePath.addRect(CGRect(x: x, y: y, width: width, height: height).applying(coordinateTransform))
    
    let frame = CTFramesetterCreateFrame(frameSetter, currentRange, framePath, nil);
    
    CTFrameDraw(frame, context)
  }
  
  // This is a standard way to pull x/y/width/height values from props and create a
  // CGRect which is commonly used for positioning elements. The modifier parameter
  // is there to support having multiple rectangle configs in the case that some draw
  // functions need that. This is necessary because the props must be flat key/value
  // pairs instead of nested objects to allow for simpler animation (preventing
  // base value mutation during animation).
  private func rectFromProps(_ props: Dictionary<String, Any>, modifier: String? = nil) -> CGRect {
    var xKey = "x"
    var yKey = "y"
    var widthKey = "width"
    var heightKey = "height"
    
    if let _modifier = modifier {
      xKey = "\(_modifier)\(xKey)"
      yKey = "\(_modifier)\(yKey)"
      widthKey = "\(_modifier)\(widthKey)"
      heightKey = "\(_modifier)\(heightKey)"
    }
    
    let x = props[xKey] as? Double ?? 0
    let y = props[yKey] as? Double ?? 0
    let width = props[widthKey] as? Double ?? 0
    let height = props[heightKey] as? Double ?? 0

    let rect = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height)).applying(coordinateTransform)
    
    return rect
  }
}
