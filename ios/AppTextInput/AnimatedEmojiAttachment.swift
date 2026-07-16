import UIKit

// Use a public UTI so the system reliably resolves the registered view provider.
// Custom UTIs can be ignored by TextKit on some iOS 16 devices, which causes the
// generic document placeholder to render instead of the live Lottie view.
public let AnimatedEmojiAttachmentFileType = "public.item"

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
    super.init(data: nil, ofType: AnimatedEmojiAttachmentFileType)
    self.bounds = bounds

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
    // iOS does not reliably call loadView() for custom NSTextAttachmentViewProvider
    // subclasses. Force it here so the container view is created and the animation
    // starts loading immediately when the attachment is first laid out.
    provider.loadView()
    log("viewProvider entityId=\(entityId) forcedLoadView viewSet=\(provider.view != nil)")
    return provider
  }

  private func log(_ message: String) {
    #if DEBUG
    let fullMessage = "AppTextInput: \(message)"
    print(fullMessage)
    AppTextInputLogger.emit(level: "info", message: fullMessage)
    #endif
  }
}
