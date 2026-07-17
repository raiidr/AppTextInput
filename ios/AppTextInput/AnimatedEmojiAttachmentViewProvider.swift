import UIKit
import Lottie

@available(iOS 15.0, *)
@objc
public class AnimatedEmojiAttachmentViewProvider: NSTextAttachmentViewProvider {

  /// In-memory cache for decoded Lottie animations so the text input does not
  /// re-download the same asset every time it is inserted or the attributed
  /// string is rebuilt.
  private static var animationCache = [String: LottieAnimation]()
  private static let animationCacheQueue = DispatchQueue(
    label: "com.raiidr.appTextInput.animatedEmojiAnimationCache"
  )

  public override init(
    textAttachment: NSTextAttachment,
    parentView: UIView?,
    textLayoutManager: NSTextLayoutManager?,
    location: NSTextLocation
  ) {
    super.init(
      textAttachment: textAttachment,
      parentView: parentView,
      textLayoutManager: textLayoutManager,
      location: location
    )
    tracksTextAttachmentViewBounds = true
  }

  public override func attachmentBounds(
    for attributes: [NSAttributedString.Key: Any],
    location: NSTextLocation,
    textContainer: NSTextContainer?,
    proposedLineFragment: CGRect,
    position: CGPoint
  ) -> CGRect {
    // Prefer sizing to the current font's line height so the attachment has
    // a meaningful size in the text layout. Fall back to proposed line fragment.
    let rect: CGRect
    if let font = attributes[.font] as? UIFont {
      let h = max(18, font.lineHeight)
      rect = CGRect(x: 0, y: (font.descender).rounded(), width: h, height: h)
    } else {
      let h = max(18, proposedLineFragment.height)
      rect = CGRect(x: 0, y: 0, width: h, height: h)
    }
    #if DEBUG
    print("AppTextInputCoreView: attachmentBounds returning \(rect)")
    #endif
    return rect
  }

  public override func loadView() {
    guard let attachment = textAttachment as? AnimatedEmojiAttachment else {
      log("loadView: attachment is not AnimatedEmojiAttachment")
      view = UIView()
      return
    }

    let entityId = attachment.entityId
    let assetKey = attachment.assetKey
    let source = attachment.animationSource
    let hasSource = source != nil && !(source?.isEmpty ?? true)
    let sourceKeys = source?.keys.sorted().joined(separator: ",") ?? "n/a"
    log("loadView id=\(entityId) assetKey=\(assetKey) fallback=\(attachment.fallback) hasSource=\(hasSource) sourceKeys=\(sourceKeys)")
    let containerView = AnimatedEmojiAttachmentContainerView(attachment: attachment)
    view = containerView

    if let cached = Self.cachedAnimation(for: entityId) {
      log("loadView: using cached animation for \(entityId)")
      containerView.showAnimation(cached)
      return
    }

    // Prefer the Lottie source data passed directly from JavaScript. This
    // reuses the same JSON that the chat message renderer already downloads
    // and caches, so the text input does not need its own network request.
    if let source = attachment.animationSource, !source.isEmpty {
      log("loadView: decoding animation from source for \(entityId), sourceType=\(type(of: source)), sourceKeys=\(source.keys.sorted().joined(separator: ","))")
      DispatchQueue.global(qos: .userInitiated).async { [weak self, weak containerView] in
        guard let self = self, let containerView = containerView else { return }

        do {
          // Use Lottie's dictionary initializer instead of JSONDecoder. The
          // server's Lottie payloads contain some numeric values as strings,
          // which Lottie's dictionary parser normalizes but JSONDecoder rejects.
          let animation = try LottieAnimation(dictionary: source)
          Self.storeAnimation(animation, for: entityId)
          self.log("loadView: decoded source animation for \(entityId) bounds=\(animation.bounds), applying")
          DispatchQueue.main.async {
            containerView.showAnimation(animation)
          }
        } catch {
          self.log("Failed to decode Lottie animation from source data for \(entityId): \(error)")
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loadAnimationFromURL(containerView: containerView, attachment: attachment)
          }
        }
      }
      return
    }

    loadAnimationFromURL(containerView: containerView, attachment: attachment)
  }

  private func loadAnimationFromURL(containerView: AnimatedEmojiAttachmentContainerView, attachment: AnimatedEmojiAttachment) {
    let entityId = attachment.entityId
    let assetKey = attachment.assetKey

    guard let url = URL(string: assetKey),
          url.scheme == "http" || url.scheme == "https" else {
      log("loadView: assetKey is not a remote URL for \(entityId), showing fallback")
      containerView.showFallback()
      return
    }

    // Keep the fallback label visible while the JSON endpoint downloads and
    // decodes. This avoids blank inline attachment slots during slow network
    // or cache-miss states.
    log("loadView: fetching animation URL for \(entityId): \(url)")
    URLSession.shared.dataTask(with: url) { [weak self, weak containerView] data, response, error in
      guard let self = self, let containerView = containerView else { return }

      if let error = error {
        self.log("Failed to download animated emoji from \(url): \(error)")
        DispatchQueue.main.async { containerView.showFallback() }
        return
      }

      if let httpResponse = response as? HTTPURLResponse,
         !(200...299).contains(httpResponse.statusCode) {
        self.log("Animated emoji request returned \(httpResponse.statusCode) for \(url)")
        DispatchQueue.main.async { containerView.showFallback() }
        return
      }

      guard let data = data else {
        self.log("Animated emoji request returned empty data for \(url)")
        DispatchQueue.main.async { containerView.showFallback() }
        return
      }

      do {
        // Use Lottie's data loader because it handles the server's mixed
        // numeric/string value representation in Lottie JSON.
        let animation = try LottieAnimation.from(data: data)
        Self.storeAnimation(animation, for: entityId)
        self.log("loadView: decoded URL animation for \(entityId) bounds=\(animation.bounds), applying")
        DispatchQueue.main.async {
          containerView.showAnimation(animation)
        }
      } catch {
        self.log("Failed to decode animated emoji JSON from \(url): \(error)")
        DispatchQueue.main.async { containerView.showFallback() }
      }
    }.resume()
  }

  private static func cachedAnimation(for key: String) -> LottieAnimation? {
    return animationCacheQueue.sync {
      animationCache[key]
    }
  }

  private static func storeAnimation(_ animation: LottieAnimation, for key: String) {
    animationCacheQueue.async {
      animationCache[key] = animation
    }
  }

  private func log(_ message: String) {
    #if DEBUG
    let fullMessage = "AppTextInputCoreView: \(message)"
    print(fullMessage)
    NSLog("%@", fullMessage)
    AppTextInputLogger.emit(level: "info", message: fullMessage)
    #endif
  }
}

private final class AnimatedEmojiAttachmentContainerView: UIView {
  private let fallbackLabel = UILabel()
  private var animationView: LottieAnimationView?
  private let attachment: AnimatedEmojiAttachment

  init(attachment: AnimatedEmojiAttachment) {
    self.attachment = attachment
    super.init(frame: .zero)
    contentScaleFactor = UIScreen.main.scale
    backgroundColor = .clear
    clipsToBounds = false
    isUserInteractionEnabled = false
    isAccessibilityElement = true
    accessibilityLabel = attachment.shortcode

    fallbackLabel.text = attachment.fallback
    // Use the Apple Color Emoji font explicitly so the fallback label always
    // shows a colored emoji, even when the system font cascade is not active.
    let fontSize = max(12, attachment.bounds.height * 0.85)
    fallbackLabel.font = UIFont(name: "AppleColorEmoji", size: fontSize)
      ?? UIFont.systemFont(ofSize: fontSize)
    fallbackLabel.textAlignment = .center
    fallbackLabel.adjustsFontSizeToFitWidth = true
    fallbackLabel.minimumScaleFactor = 0.5
    fallbackLabel.baselineAdjustment = .alignCenters
    addSubview(fallbackLabel)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    // TextKit asks the provider for its bounds before it assigns the final
    // frame. Use the attachment's declared size here instead of the current
    // bounds (which are zero during the first layout pass).
    let size = attachment.bounds.size
    return CGSize(width: max(size.width, 1), height: max(size.height, 1))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // TextKit may not have sized the container on the first layout pass (e.g.
    // when showAnimation is called before the text layout completes). Fall back
    // to the attachment's declared bounds so the fallback label or Lottie view
    // is still visible and gets corrected once the final size arrives.
    let layoutBounds = bounds.isEmpty
      ? CGRect(origin: .zero, size: intrinsicContentSize)
      : bounds
    fallbackLabel.frame = layoutBounds
    animationView?.frame = layoutBounds

    let dynamicFontSize = max(12, layoutBounds.height * 0.85)
    if abs(fallbackLabel.font.pointSize - dynamicFontSize) > 0.1 {
      fallbackLabel.font = UIFont(name: "AppleColorEmoji", size: dynamicFontSize)
        ?? UIFont.systemFont(ofSize: dynamicFontSize)
    }

    #if DEBUG
    print("AppTextInputCoreView: layoutSubviews bounds=\(bounds) labelFrame=\(fallbackLabel.frame) animFrame=\(animationView?.frame ?? .zero)")
    #endif
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    #if DEBUG
    print("AppTextInputCoreView: didMoveToWindow window=\(String(describing: window))")
    #endif
    if window == nil {
      animationView?.pause()
      #if DEBUG
      print("AppTextInputCoreView: animation paused (window nil)")
      #endif
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.animationView?.isHidden = false
        self?.animationView?.play()
        #if DEBUG
        print("AppTextInputCoreView: animation play() dispatched on next runloop")
        #endif
      }
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    #if DEBUG
    print("AppTextInputCoreView: didMoveToSuperview superview=\(String(describing: superview))")
    #endif
    setNeedsLayout()
    layoutIfNeeded()
  }

  func showAnimation(_ animation: LottieAnimation) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in
        self?.showAnimation(animation)
      }
      return
    }

    log("showAnimation id=\(attachment.entityId) animationSize=\(animation.bounds.size)")

    let nextAnimationView = LottieAnimationView(
        animation: animation,
        configuration: LottieConfiguration(renderingEngine: .mainThread)
    )
    nextAnimationView.translatesAutoresizingMaskIntoConstraints = true
    nextAnimationView.backgroundColor = .clear
    nextAnimationView.isOpaque = false
    nextAnimationView.contentMode = .scaleAspectFit
    nextAnimationView.loopMode = .loop
    nextAnimationView.backgroundBehavior = .pauseAndRestore
    nextAnimationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    animationView?.removeFromSuperview()
    addSubview(nextAnimationView)
    bringSubviewToFront(nextAnimationView)
    animationView = nextAnimationView

    setNeedsLayout()
    layoutIfNeeded()

    fallbackLabel.isHidden = true

    nextAnimationView.isHidden = false
    nextAnimationView.currentProgress = 0
    nextAnimationView.forceDisplayUpdate()

    DispatchQueue.main.async { [weak nextAnimationView] in
        nextAnimationView?.play(fromProgress: 0, toProgress: 1, loopMode: .loop)
    }
  }

  func showFallback() {
    animationView?.isHidden = true
    animationView?.pause()
    fallbackLabel.isHidden = false
    bringSubviewToFront(fallbackLabel)
  }

  private func log(_ message: String) {
    #if DEBUG
    let fullMessage = "AppTextInputCoreView: AnimatedEmojiAttachmentContainerView: \(message)"
    AppTextInputLogger.emit(level: "info", message: fullMessage)
    #endif
  }
}
