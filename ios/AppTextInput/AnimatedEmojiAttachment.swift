import UIKit

// The attachment carries PNG fallback contents, so the file type must describe
// those contents. A nil content payload creates an attachment without document
// contents and can leave `fileType` nil even when a UTI is supplied to init.
public let AnimatedEmojiAttachmentFileType = "public.png"

@objc
public class AnimatedEmojiAttachment: NSTextAttachment {
  public let entityId: String
  public let shortcode: String
  public let fallback: String
  public let assetKey: String
  public let animationSource: [String: Any]?

  public init(
    entityId: String,
    shortcode: String,
    fallback: String,
    assetKey: String,
    animationSource: [String: Any]? = nil,
    bounds: CGRect
  ) {
    self.entityId = entityId
    self.shortcode = shortcode
    self.fallback = fallback
    self.assetKey = assetKey
    self.animationSource = animationSource
    let fallbackData = Self.renderFallbackImage(fallback, bounds: bounds).pngData() ?? Data()
    super.init(data: fallbackData, ofType: AnimatedEmojiAttachmentFileType)
    self.bounds = bounds

    #if DEBUG
    log("AnimatedEmojiAttachment.init fileTypeConstant=\(AnimatedEmojiAttachmentFileType) fileTypeAfterSuper=\(String(describing: fileType)) contentsSet=\(contents != nil)")
    #endif

    if #available(iOS 15.0, *) {
      // Explicitly opt-in to the view-provider path. Although the default is
      // true, being explicit ensures TextKit asks for our custom view instead
      // of rendering the generic document placeholder.
      allowsTextAttachmentView = true
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @available(iOS 15.0, *)
  public override var usesTextAttachmentView: Bool {
    // Only force the view-provider path on iOS 16+, where TextKit 2 reliably
    // hosts the live Lottie view. On iOS 15 the default TextKit 1 path does not
    // support NSTextAttachmentViewProvider, so we let the fallback image
    // render instead. Without this override on iOS 16+, a non-nil `image` causes
    // the default implementation to return false, which would render the
    // static fallback image instead of the animated view.
    let value: Bool
    if #available(iOS 16.0, *) {
      value = true
    } else {
      value = false
    }
    log("usesTextAttachmentView entityId=\(entityId) imageSet=\(image != nil) returns=\(value)")
    return value
  }

  @available(iOS 15.0, *)
  public override func viewProvider(
    for parentView: UIView?,
    location: NSTextLocation,
    textContainer: NSTextContainer?
  ) -> NSTextAttachmentViewProvider? {
    let hasLayoutManager = textContainer?.textLayoutManager != nil
    log("viewProvider entityId=\(entityId) parentViewSet=\(parentView != nil) textLayoutManagerSet=\(hasLayoutManager)")
    var layoutManager: NSTextLayoutManager? = nil
    if #available(iOS 16.0, *) {
      layoutManager = textContainer?.textLayoutManager
    }
    let provider = AnimatedEmojiAttachmentViewProvider(
      textAttachment: self,
      parentView: parentView,
      textLayoutManager: layoutManager,
      location: location
    )
    // TextKit owns the provider view lifecycle. In particular, loadView() must
    // be invoked by TextKit after it has attached the provider to the layout;
    // calling it here creates the view before TextKit can size and host it.
    log("viewProvider entityId=\(entityId) providerCreated")
    return provider
  }

  private func log(_ message: String) {
    #if DEBUG
    let fullMessage = "AppTextInput: \(message)"
    print(fullMessage)
    AppTextInputLogger.emit(level: "info", message: fullMessage)
    #endif
  }

  private static func renderFallbackImage(_ fallback: String, bounds: CGRect) -> UIImage {
    let size = CGSize(width: max(bounds.width, 1), height: max(bounds.height, 1))
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      let font = UIFont(name: "AppleColorEmoji", size: size.height * 0.85)
        ?? UIFont.systemFont(ofSize: size.height * 0.85)
      let attributes: [NSAttributedString.Key: Any] = [.font: font]
      let textSize = (fallback as NSString).size(withAttributes: attributes)
      let origin = CGPoint(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2
      )
      (fallback as NSString).draw(at: origin, withAttributes: attributes)
    }
  }
}
