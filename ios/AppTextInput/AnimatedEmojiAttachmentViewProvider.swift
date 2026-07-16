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
    return textAttachment?.bounds ?? CGRect(x: 0, y: 0, width: 24, height: 24)
  }

  public override func loadView() {
    guard view == nil else {
      log("loadView early return, view already set")
      return
    }
    log("loadView called textAttachment=\(String(describing: type(of: textAttachment)))")
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
          // Decode the dictionary directly to avoid a round-trip through
          // JSONSerialization, which can fail on edge-case values and adds
          // unnecessary overhead for large Lottie files.
          let animation = try LottieAnimation(dictionary: source)
          Self.storeAnimation(animation, for: entityId)
          self.log("loadView: decoded source animation for \(entityId), applying")
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
        let animation = try LottieAnimation.from(data: data)
        Self.storeAnimation(animation, for: entityId)
        self.log("loadView: decoded URL animation for \(entityId), applying")
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

  init(attachment: AnimatedEmojiAttachment) {
    super.init(frame: .zero)
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

  override func layoutSubviews() {
    super.layoutSubviews()
    fallbackLabel.frame = bounds
    animationView?.frame = bounds
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      animationView?.pause()
    } else {
      animationView?.play()
    }
  }

  func showAnimation(_ animation: LottieAnimation) {
    let nextAnimationView = animationView ?? LottieAnimationView(
      configuration: LottieConfiguration(renderingEngine: .automatic)
    )
    if animationView == nil {
      nextAnimationView.contentMode = .scaleAspectFit
      nextAnimationView.loopMode = .loop
      nextAnimationView.backgroundBehavior = .pauseAndRestore
      nextAnimationView.frame = bounds
      addSubview(nextAnimationView)
      animationView = nextAnimationView
    }

    nextAnimationView.animation = animation
    fallbackLabel.isHidden = true
    nextAnimationView.isHidden = false
    nextAnimationView.play()
  }

  func showAnimationView(_ nextAnimationView: LottieAnimationView) {
    guard nextAnimationView.animation != nil else {
      showFallback()
      return
    }

    animationView?.removeFromSuperview()
    nextAnimationView.configuration = LottieConfiguration(renderingEngine: .automatic)
    nextAnimationView.contentMode = .scaleAspectFit
    nextAnimationView.loopMode = .loop
    nextAnimationView.backgroundBehavior = .pauseAndRestore
    nextAnimationView.frame = bounds
    addSubview(nextAnimationView)
    animationView = nextAnimationView
    fallbackLabel.isHidden = true
    nextAnimationView.play()
  }

  func showFallback() {
    animationView?.isHidden = true
    animationView?.pause()
    fallbackLabel.isHidden = false
  }
}
