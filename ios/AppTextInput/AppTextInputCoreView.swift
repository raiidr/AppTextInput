import UIKit
import Lottie

// Simple, thread-safe file logger for AppTextInput messages.
fileprivate final class AppTextInputFileLogger {
  static let shared = AppTextInputFileLogger()

  private let queue = DispatchQueue(label: "com.apptextinput.filelogger", qos: .utility)
  private let logURL: URL
  private let dateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private init() {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    self.logURL = caches.appendingPathComponent("AppTextInput.log")
    // Ensure the file exists so later appends succeed.
    if !FileManager.default.fileExists(atPath: logURL.path) {
      FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: nil)
    }
  }

  func log(level: String = "info", message: String) {
    let ts = dateFormatter.string(from: Date())
    let line = "[\(ts)] [\(level)] \(message)\n"
    let data = Data(line.utf8)
    queue.async { [logURL] in
      do {
        let handle = try FileHandle(forWritingTo: logURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
      } catch {
        // Intentionally ignore errors to avoid impacting app behavior.
      }
    }
  }

  // Expose the file URL for debugging or external retrieval if needed.
  var fileURL: URL { logURL }
}

/// Lightweight RCTEventEmitter used to forward AppTextInput native logs to the
/// JavaScript console. Only emits in DEBUG builds and only when a JS listener
/// is registered, so it has no impact on production performance.
@objc(AppTextInputLogger)
public class AppTextInputLogger: RCTEventEmitter {
  public static var shared: AppTextInputLogger?

  public override init() {
    super.init()
    Self.shared = self
  }

  /// Emits a log event to any JS subscriber. Safe to call from any thread.
  public static func emit(level: String, message: String) {
    #if DEBUG
    // Forward to JS if available; avoid noisy console printing. Persist to file if no shared instance.
    guard let shared = shared else {
      AppTextInputFileLogger.shared.log(level: level, message: "[AppTextInputLogger] no shared instance, dropping log: \(message)")
      return
    }
    shared.sendEvent(
      withName: "onAppTextInputLog",
      body: [
        "level": level,
        "message": message,
        "timestamp": Date().timeIntervalSince1970 * 1000,
      ]
    )
    #endif
  }

  @objc override public static func requiresMainQueueSetup() -> Bool {
    return true
  }

  @objc override public func supportedEvents() -> [String]! {
    return ["onAppTextInputLog"]
  }
}

struct AnimatedEmojiEntity: Codable, Equatable {
  let type: String
  let id: String
  let shortcode: String
  let fallback: String
  let assetKey: String
    var offset: Int
  let length: Int
}

@objc
public class AppTextInputCoreView: UIView {
  // NSTextAttachmentViewProvider (inline Lottie views) only renders under
  // TextKit 2, so the text view must be created with a text layout manager.
  private let textView: PlaceholderTextView = {
    // NSTextAttachmentViewProvider only reliably renders inline views on iOS 16+.
    if #available(iOS 16.0, *) {
      return PlaceholderTextView.textKit2View()
    }
    return PlaceholderTextView()
  }()

  private var currentText: String = ""
  private var currentEntities: [AnimatedEmojiEntity] = []
  private var currentRevision: Int = 0
  private var currentSelection: [String: Int] = ["start": 0, "end": 0]
  private var animationSources: [String: Any] = [:]

  private var isApplyingProps = false
  private var isReduceMotionEnabled: Bool {
    UIAccessibility.isReduceMotionEnabled
  }

  @objc public var onAppTextInputChange: (([String: Any]) -> Void)?
  @objc public var onSelectionChangeNative: (([String: Any]) -> Void)?
  @objc public var onFocus: (([String: Any]) -> Void)?
  @objc public var onBlur: (([String: Any]) -> Void)?
  @objc public var onSubmitEditing: (([String: Any]) -> Void)?
  @objc public var onShortcodeQueryChange: (([String: Any]) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    Self.ensureAttachmentProviderRegistered()
    setupTextView()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupTextView() {
    textView.delegate = self
    textView.backgroundColor = .clear
    textView.textContainer.lineFragmentPadding = 0
    if #available(iOS 16.0, *) {
      let isTextKit2 = textView.textLayoutManager != nil
      log("setupTextView textKit2=\(isTextKit2) usingTextLayoutManager=\(textView.textLayoutManager != nil)")
    } else {
      log("setupTextView iOS 15 TextKit 1")
    }
    addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private static var didRegisterAttachmentProvider = false

  private static func ensureAttachmentProviderRegistered() {
    if Thread.isMainThread {
      Self.registerAttachmentProvider()
    } else {
      DispatchQueue.main.sync {
        Self.registerAttachmentProvider()
      }
    }
  }

  private static func registerAttachmentProvider() {
    guard !didRegisterAttachmentProvider else { return }
    didRegisterAttachmentProvider = true

    if #available(iOS 15.0, *) {
      let types = [
        AnimatedEmojiAttachmentFileType,
        "com.apple.uikit.nstextattachment",
        "public.item",
        "public.data",
        "public.json",
        "public.jpeg"
      ]
      for t in types {
        NSTextAttachment.registerViewProviderClass(AnimatedEmojiAttachmentViewProvider.self, forFileType: t)
      }
      #if DEBUG
      AppTextInputFileLogger.shared.log(level: "info", message: "AppTextInputCoreView: Registered attachment view provider for types: \(types.joined(separator: ","))")
      #endif
    }
  }

  // MARK: - Props

  @objc
  public func setText(_ text: String) {
    guard text != currentText else { return }
    log("setText length=\(text.count) currentEntities=\(currentEntities.count)")
    currentText = text
    rebuildAttributedText()
  }

  @objc
  public func setEntities(_ entitiesJson: String) {
    let entities = decodeEntities(entitiesJson)
    guard entities != currentEntities else { return }
    log("setEntities count=\(entities.count)")
    currentEntities = entities
    rebuildAttributedText()
  }

  @objc
  public func setRevision(_ revision: Int) {
    currentRevision = revision
  }

  @objc
  public func setSelection(_ selection: [String: Any]) {
    currentSelection = [
      "start": (selection["start"] as? NSNumber)?.intValue ?? 0,
      "end": (selection["end"] as? NSNumber)?.intValue ?? 0,
    ]
    applySelection()
  }

  @objc
  public func setAnimationSources(_ sources: [String: Any]?) {
    log("setAnimationSources called sourcesCount=\(sources?.count ?? 0)")
    let normalized: [String: Any] = sources ?? [:]
    if areAnimationSourcesEqual(normalized, animationSources) {
      log("setAnimationSources skipped, sources unchanged")
      return
    }
    animationSources = normalized
    log("setAnimationSources count=\(animationSources.count) ids=\(animationSources.keys.sorted().joined(separator: ","))")
    // Rebuild the attributed text so any newly provided sources are applied to
    // their corresponding inline attachments immediately.
    rebuildAttributedText()
  }

  private func areAnimationSourcesEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
    // Quick path: compare top-level keys
    if lhs.keys.sorted() != rhs.keys.sorted() { return false }
    // Values are bridged from Objective-C (NSDictionary/NSArray/NSNumber/NSString),
    // so compare them using isEqual which handles nested collections.
    for key in lhs.keys {
      let leftValue = lhs[key] ?? NSNull()
      let rightValue = rhs[key] ?? NSNull()
      guard let leftObj = leftValue as? NSObject, let rightObj = rightValue as? NSObject else {
        return false
      }
      if !leftObj.isEqual(rightObj) {
        return false
      }
    }
    return true
  }

  @objc
  public func setPlaceholder(_ placeholder: String?) {
    textView.placeholder = placeholder
  }

  @objc
  public func setPlaceholderTextColor(_ color: UIColor?) {
    textView.placeholderTextColor = color
  }

  @objc
  public func setMultiline(_ multiline: Bool) {
    textView.isScrollEnabled = multiline
    textView.textContainer.maximumNumberOfLines = multiline ? 0 : 1
  }

  @objc
  public func setEditable(_ editable: Bool) {
    textView.isEditable = editable
  }

  @objc
  public func setAutoFocus(_ autoFocus: Bool) {
    if autoFocus {
      textView.becomeFirstResponder()
    }
  }

  @objc
  public func setSelectionColor(_ color: UIColor?) {
    textView.tintColor = color
  }

  @objc
  public func setColor(_ color: UIColor?) {
    textView.textColor = color
    // Rebuild so the attributed string picks up the new foreground color and any
    // fallback emoji images are regenerated at the correct tint.
    rebuildAttributedText()
  }

  @objc
  public func setFontSize(_ fontSize: NSNumber?) {
    let size = fontSize.flatMap { CGFloat(truncating: $0) } ?? UIFont.labelFontSize
    textView.font = UIFont.systemFont(ofSize: size)
    // Rebuild so emoji attachment bounds are recalculated for the new font metrics.
    rebuildAttributedText()
  }

  @objc
  public func setKeyboardType(_ keyboardType: String?) {
    textView.keyboardType = uiKeyboardType(from: keyboardType)
  }

  @objc
  public func setReturnKeyType(_ returnKeyType: String?) {
    textView.returnKeyType = uiReturnKeyType(from: returnKeyType)
  }

  @objc
  public func setSecureTextEntry(_ secureTextEntry: Bool) {
    textView.isSecureTextEntry = secureTextEntry
  }

  @objc
  public func setNumberOfLines(_ numberOfLines: Int) {
    textView.textContainer.maximumNumberOfLines = numberOfLines
  }

  @objc
  public func setTextAlign(_ textAlign: String?) {
    textView.textAlignment = uiTextAlignment(from: textAlign)
  }

  @objc
  public func setAutoCapitalize(_ autoCapitalize: String?) {
    textView.autocapitalizationType = uiAutoCapitalizationType(from: autoCapitalize)
  }

  @objc
  public func setAutoCorrect(_ autoCorrect: Bool) {
    textView.autocorrectionType = autoCorrect ? .yes : .no
  }

  @objc
  public func setAutoComplete(_ autoComplete: String?) {
    // UITextContentType handles autocomplete suggestions.
    textView.textContentType = autoComplete.flatMap { UITextContentType(rawValue: $0) }
  }

  @objc
  public func setTextContentType(_ textContentType: String?) {
    textView.textContentType = textContentType.flatMap { UITextContentType(rawValue: $0) }
  }

  @objc
  public func setSubmitBehavior(_ submitBehavior: String?) {
    // Stored for future use; submit behavior is mostly handled by the delegate.
  }

  // MARK: - Commands

  @objc
  public func focus() {
    textView.becomeFirstResponder()
  }

  @objc
  public func blur() {
    textView.resignFirstResponder()
  }

  @objc
  public func clear() {
    currentText = ""
    currentEntities = []
    currentSelection = ["start": 0, "end": 0]
    currentRevision += 1
    rebuildAttributedText()
    emitChange()
  }

  @objc(appIsFocused)
  public func isFocused() -> Bool {
    return textView.isFirstResponder
  }

  @objc
  public func setSelectionCommand(_ start: Int, end: Int) {
    currentSelection = ["start": start, "end": end]
    applySelection()
  }

  // Objective-C callers use `animationSource:`; Swift keeps the more descriptive
  // internal name `animationSourceJson`.
  @objc(insertAnimatedEmoji:shortcode:fallback:assetKey:animationSource:start:end:)
  public func insertAnimatedEmoji(
    _ id: String,
    shortcode: String,
    fallback: String,
    assetKey: String,
    animationSource animationSourceJson: String,
    start: Int,
    end: Int
  ) {
    let range = NSRange(location: min(start, end), length: abs(end - start))
    let hasSource = !animationSourceJson.isEmpty
    log("insertAnimatedEmoji id=\(id) range=\(range.location),\(range.length) assetKey=\(assetKey) hasSource=\(hasSource)")

    // If JS passed the cached Lottie source directly, seed the in-memory source
    // map so rebuildAttributedText can use it immediately without a URL fetch.
    if hasSource,
       let data = animationSourceJson.data(using: .utf8),
       let source = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      animationSources[id] = source
    }

    // Entity offsets are relative to the inserted text because replaceRangeCommand
    // shifts them by the replacement range location.
    replaceRangeCommand(range, text: "\u{FFFC}", entitiesJson: encodeEntities([
      AnimatedEmojiEntity(
        type: "animated-emoji",
        id: id,
        shortcode: shortcode,
        fallback: fallback,
        assetKey: assetKey,
        offset: 0,
        length: 1
      )
    ]))
  }

  @objc
  public func replaceRangeCommand(_ range: NSRange, text: String, entitiesJson: String) {
    let safeRange = safeRange(range, in: currentText)
    var newText = currentText
    let nsText = newText as NSString
    newText = nsText.replacingCharacters(in: safeRange, with: text)

    var insertedEntities = decodeEntities(entitiesJson)
    insertedEntities = insertedEntities.map { entity in
      var mutable = entity
      mutable.offset = safeRange.location + entity.offset
      return mutable
    }

    let delta = (text as NSString).length - safeRange.length
    currentEntities = shiftEntities(after: safeRange, by: delta, removingIn: safeRange)
    currentEntities.append(contentsOf: insertedEntities)
    currentEntities.sort { $0.offset < $1.offset }
    currentText = newText
    currentSelection = ["start": safeRange.location + (text as NSString).length, "end": safeRange.location + (text as NSString).length]
    currentRevision += 1
    log("replaceRangeCommand safeRange=\(safeRange.location),\(safeRange.length) textLen=\(text.count) newEntityCount=\(currentEntities.count)")

    rebuildAttributedText()
    emitChange()
  }

  // MARK: - Helpers

  private func decodeEntities(_ json: String) -> [AnimatedEmojiEntity] {
    guard let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([AnimatedEmojiEntity].self, from: data)) ?? []
  }

  private func encodeEntities(_ entities: [AnimatedEmojiEntity]) -> String {
    guard let data = try? JSONEncoder().encode(entities) else { return "[]" }
    return String(data: data, encoding: .utf8) ?? "[]"
  }

  private func safeRange(_ range: NSRange, in text: String) -> NSRange {
    let nsText = text as NSString
    let maxLength = nsText.length
    let location = max(0, min(range.location, maxLength))
    let length = max(0, min(range.length, maxLength - location))
    return NSRange(location: location, length: length)
  }

  private func shiftEntities(
    after range: NSRange,
    by delta: Int,
    removingIn removedRange: NSRange
  ) -> [AnimatedEmojiEntity] {
    return currentEntities.compactMap { entity in
      let entityEnd = entity.offset + entity.length
      if entity.offset >= removedRange.location + removedRange.length {
        var shifted = entity
        shifted.offset += delta
        return shifted
      }
      if entityEnd <= removedRange.location {
        return entity
      }
      return nil
    }
  }

  private func rebuildAttributedText() {
    let font = textView.font ?? UIFont.systemFont(ofSize: UIFont.labelFontSize)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textView.textColor ?? UIColor.label,
    ]
    let attributed = NSMutableAttributedString(string: currentText, attributes: attributes)

    let nsText = currentText as NSString
    var attachmentCount = 0
    for entity in currentEntities.sorted(by: { $0.offset > $1.offset }) {
      guard entity.offset >= 0, entity.offset < nsText.length else { continue }
      if nsText.character(at: entity.offset) != 0xFFFC { continue }

      let attachmentBounds = emojiAttachmentBounds(for: font)
      let attachment = AnimatedEmojiAttachment(
        entityId: entity.id,
        shortcode: entity.shortcode,
        fallback: entity.fallback,
        assetKey: entity.assetKey,
        animationSource: animationSources[entity.id] as? [String: Any],
        bounds: attachmentBounds
      )

      if let fileType = attachment.fileType {
        log("Created attachment fileType=\(fileType) for entityId=\(entity.id) contentsSet=\(attachment.contents != nil)")
      } else {
        log("Created attachment has nil fileType for entityId=\(entity.id) contentsSet=\(attachment.contents != nil)")
      }

      let attachmentString = NSAttributedString(attachment: attachment)
     attributed.replaceCharacters(in: NSRange(location: entity.offset, length: 1), with: attachmentString)
     attachmentCount += 1

    }

    log("rebuildAttributedText textLen=\(currentText.count) entities=\(currentEntities.count) attachments=\(attachmentCount)")

isApplyingProps = true
textView.attributedText = attributed
applySelection()

// Force a layout pass to encourage TextKit 2 to instantiate view providers.
DispatchQueue.main.async { [weak textView] in
  textView?.setNeedsLayout()
  textView?.layoutIfNeeded()
}
isApplyingProps = false
  }

  private func emojiAttachmentBounds(for font: UIFont) -> CGRect {
    let fontSize = max(font.pointSize, 1)
    let size = fontSize * 1.35
    let originY = font.descender * 0.25
    return CGRect(x: 0, y: originY, width: max(size, 1), height: max(size, 1))
  }

  private func applySelection() {
    let start = max(0, min(currentSelection["start"] ?? 0, (currentText as NSString).length))
    let end = max(start, min(currentSelection["end"] ?? start, (currentText as NSString).length))
    textView.selectedRange = normalizeSelection(NSRange(location: start, length: end - start))
  }

  private func normalizeSelection(_ range: NSRange) -> NSRange {
    let nsText = currentText as NSString
    var start = max(0, min(range.location, nsText.length))
    var end = max(start, min(range.location + range.length, nsText.length))

    for entity in currentEntities {
      let entityStart = entity.offset
      let entityEnd = entity.offset + entity.length
      if start > entityStart && start < entityEnd {
        start = entityEnd
      }
      if end > entityStart && end < entityEnd {
        end = entityStart
      }
      if start >= end {
        end = start
      }
    }
    return NSRange(location: start, length: end - start)
  }

  private func extractEntitiesFromTextView() -> [AnimatedEmojiEntity] {
    let nsText = textView.attributedText.string as NSString
    let length = nsText.length
    var entities: [AnimatedEmojiEntity] = []
    var index = 0
    while index < length {
      if nsText.character(at: index) == 0xFFFC {
        var effectiveRange = NSRange(location: index, length: 1)
        let attributes = textView.attributedText.attributes(at: index, effectiveRange: &effectiveRange)
        if let attachment = attributes[.attachment] as? AnimatedEmojiAttachment {
          entities.append(
            AnimatedEmojiEntity(
              type: "animated-emoji",
              id: attachment.entityId,
              shortcode: attachment.shortcode,
              fallback: attachment.fallback,
              assetKey: attachment.assetKey,
              offset: index,
              length: 1
            )
          )
        }
      }
      index += 1
    }
    return entities
  }

  private func emitChange() {
    currentSelection = ["start": textView.selectedRange.location, "end": textView.selectedRange.location + textView.selectedRange.length]
    let payload: [String: Any] = [
      "text": currentText,
      "entities": encodeEntities(currentEntities),
      "revision": currentRevision,
      "selection": currentSelection,
    ]
    onAppTextInputChange?(payload)
  }

  private func emitSelectionChange() {
    let payload: [String: Any] = [
      "selection": [
        "start": textView.selectedRange.location,
        "end": textView.selectedRange.location + textView.selectedRange.length,
      ],
    ]
    onSelectionChangeNative?(payload)
  }

  private func emitShortcodeQueryChange() {
    let text = currentText as NSString
    let caret = textView.selectedRange.location
    guard caret > 0, caret <= text.length else {
      onShortcodeQueryChange?(["query": NSNull(), "start": 0, "end": 0])
      return
    }
    var start = caret - 1
    while start >= 0 {
      guard let scalar = UnicodeScalar(text.character(at: start)) else {
        onShortcodeQueryChange?(["query": NSNull(), "start": 0, "end": 0])
        return
      }
      let char = Character(scalar)
      if char == ":" {
        break
      }
      if !char.isLetter && !char.isNumber && char != "_" && char != "-" {
        onShortcodeQueryChange?(["query": NSNull(), "start": 0, "end": 0])
        return
      }
      start -= 1
    }
    guard start >= 0, text.character(at: start) == 0x3A else {
      onShortcodeQueryChange?(["query": NSNull(), "start": 0, "end": 0])
      return
    }
    let query = text.substring(with: NSRange(location: start + 1, length: caret - start - 1))
    onShortcodeQueryChange?([
      "query": query,
      "start": start,
      "end": caret,
    ])
  }

  private func log(_ message: String) {
    #if DEBUG
    let fullMessage = "AppTextInputCoreView: \(message)"
    // Write to file to avoid console noise.
    AppTextInputFileLogger.shared.log(level: "info", message: fullMessage)
    // Still forward to JS listeners for in-app visibility if needed.
    AppTextInputLogger.emit(level: "info", message: fullMessage)
    #endif
  }
}

// MARK: - UITextViewDelegate

extension AppTextInputCoreView: UITextViewDelegate {
  public func textViewDidChange(_ textView: UITextView) {
    guard !isApplyingProps else { return }
    currentText = textView.attributedText.string
    currentEntities = extractEntitiesFromTextView()
    currentRevision += 1
    emitChange()
    emitShortcodeQueryChange()
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    guard !isApplyingProps else { return }
    let normalized = normalizeSelection(textView.selectedRange)
    if !NSEqualRanges(normalized, textView.selectedRange) {
      textView.selectedRange = normalized
    }
    emitSelectionChange()
    emitShortcodeQueryChange()
  }

  public func textViewDidBeginEditing(_ textView: UITextView) {
    onFocus?([:])
  }

  public func textViewDidEndEditing(_ textView: UITextView) {
    onBlur?([:])
  }

  public func textView(
    _ textView: UITextView,
    shouldChangeTextIn range: NSRange,
    replacementText text: String
  ) -> Bool {
    // Normalize deletions that partially intersect an entity.
    let normalized = normalizeSelection(range)
    if !NSEqualRanges(normalized, range) {
      let newText = (currentText as NSString).replacingCharacters(in: normalized, with: text)
      let delta = (text as NSString).length - normalized.length
      currentEntities = shiftEntities(after: normalized, by: delta, removingIn: normalized)
      currentText = newText
      currentSelection = ["start": normalized.location + (text as NSString).length, "end": normalized.location + (text as NSString).length]
      currentRevision += 1
      rebuildAttributedText()
      emitChange()
      return false
    }
    return true
  }

  public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
    return true
  }
}

// MARK: - Prop mapping helpers

private func uiKeyboardType(from value: String?) -> UIKeyboardType {
  switch value {
  case "default": return .default
  case "number-pad": return .numberPad
  case "decimal-pad": return .decimalPad
  case "numeric": return .decimalPad
  case "email-address": return .emailAddress
  case "phone-pad": return .phonePad
  case "url": return .URL
  case "ascii-capable": return .asciiCapable
  case "numbers-and-punctuation": return .numbersAndPunctuation
  case "name-phone-pad": return .namePhonePad
  case "twitter": return .twitter
  case "web-search": return .webSearch
  case "ascii-capable-number-pad": return .asciiCapableNumberPad
  default: return .default
  }
}

private func uiReturnKeyType(from value: String?) -> UIReturnKeyType {
  switch value {
  case "done": return .done
  case "go": return .go
  case "next": return .next
  case "search": return .search
  case "send": return .send
  case "none": return .default
  case "continue": return .continue
  case "emergency-call": return .emergencyCall
  case "google": return .google
  case "join": return .join
  case "route": return .route
  case "yahoo": return .yahoo
  default: return .default
  }
}

private func uiTextAlignment(from value: String?) -> NSTextAlignment {
  switch value {
  case "left": return .left
  case "center": return .center
  case "right": return .right
  case "justify": return .justified
  default: return .natural
  }
}

private func uiAutoCapitalizationType(from value: String?) -> UITextAutocapitalizationType {
  switch value {
  case "none": return .none
  case "sentences": return .sentences
  case "words": return .words
  case "characters": return .allCharacters
  default: return .sentences
  }
}
