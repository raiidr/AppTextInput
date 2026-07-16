import UIKit
import Lottie

struct AnimatedEmojiEntity: Codable {
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
  private let textView = PlaceholderTextView()

  private var currentText: String = ""
  private var currentEntities: [AnimatedEmojiEntity] = []
  private var currentRevision: Int = 0
  private var currentSelection: [String: Int] = ["start": 0, "end": 0]

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
    setupTextView()
    registerAttachmentProvider()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupTextView() {
    textView.delegate = self
    textView.backgroundColor = .clear
    textView.textContainer.lineFragmentPadding = 0
    addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: trailingAnchor),
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func registerAttachmentProvider() {
    if #available(iOS 15.0, *) {
      NSTextAttachment.registerViewProviderClass(
        AnimatedEmojiAttachmentViewProvider.self,
        forFileType: AnimatedEmojiAttachmentFileType
      )
    }
  }

  // MARK: - Props

  @objc
  public func setText(_ text: String) {
    guard text != currentText else { return }
    currentText = text
    rebuildAttributedText()
  }

  @objc
  public func setEntities(_ entitiesJson: String) {
    let entities = decodeEntities(entitiesJson)
    guard entitiesJson != encodeEntities(currentEntities) else { return }
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

  @objc
  public func insertAnimatedEmoji(
    _ id: String,
    shortcode: String,
    fallback: String,
    assetKey: String,
    start: Int,
    end: Int
  ) {
    let range = NSRange(location: min(start, end), length: abs(end - start))
    replaceRangeCommand(range, text: "\u{FFFC}", entitiesJson: encodeEntities([
      AnimatedEmojiEntity(
        type: "animated-emoji",
        id: id,
        shortcode: shortcode,
        fallback: fallback,
        assetKey: assetKey,
        offset: range.location,
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
    for entity in currentEntities.sorted(by: { $0.offset > $1.offset }) {
      guard entity.offset >= 0, entity.offset < nsText.length else { continue }
      if nsText.character(at: entity.offset) != 0xFFFC { continue }

      let attachmentBounds = emojiAttachmentBounds(for: font)
      let attachment = AnimatedEmojiAttachment(
        entityId: entity.id,
        shortcode: entity.shortcode,
        fallback: entity.fallback,
        assetKey: entity.assetKey,
        bounds: attachmentBounds
      )
      let attachmentString = NSAttributedString(attachment: attachment)
      attributed.replaceCharacters(in: NSRange(location: entity.offset, length: 1), with: attachmentString)
    }

    isApplyingProps = true
    textView.attributedText = attributed
    applySelection()
    isApplyingProps = false
  }

  private func emojiAttachmentBounds(for font: UIFont) -> CGRect {
    let size = font.pointSize * 1.2
    let originY = font.descender * 0.25
    return CGRect(x: 0, y: originY, width: size, height: size)
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


