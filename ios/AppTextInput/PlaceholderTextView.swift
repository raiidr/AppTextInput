import UIKit

final class PlaceholderTextView: UITextView {
  /// Creates a TextKit 2 backed text view when running on iOS 16+.
  /// NSTextAttachmentViewProvider only renders inline views under TextKit 2,
  /// so we use the dedicated iOS 16 initializer instead of the frame/container
  /// path, which can fall back to TextKit 1 for UITextView subclasses.
  @available(iOS 16.0, *)
  static func textKit2View() -> PlaceholderTextView {
    return PlaceholderTextView(usingTextLayoutManager: true)
  }

  var placeholder: String? {
    didSet { updatePlaceholder() }
  }

  var placeholderTextColor: UIColor? {
    didSet { updatePlaceholder() }
  }

  private let placeholderLabel = UILabel()

  override var text: String! {
    didSet { updatePlaceholderVisibility() }
  }

  override var attributedText: NSAttributedString! {
    didSet { updatePlaceholderVisibility() }
  }

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    setupPlaceholder()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupPlaceholder() {
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.numberOfLines = 0
    placeholderLabel.isUserInteractionEnabled = false
    addSubview(placeholderLabel)

    NSLayoutConstraint.activate([
      placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainerInset.left + 4),
      placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -(textContainerInset.right + 4)),
      placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: textContainerInset.top),
    ])

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(textDidChange),
      name: UITextView.textDidChangeNotification,
      object: self
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func updatePlaceholder() {
    placeholderLabel.text = placeholder
    placeholderLabel.textColor = placeholderTextColor ?? UIColor.placeholderText
    placeholderLabel.font = font
    updatePlaceholderVisibility()
  }

  private func updatePlaceholderVisibility() {
    placeholderLabel.isHidden = !(text?.isEmpty ?? true)
  }

  @objc private func textDidChange() {
    updatePlaceholderVisibility()
  }
}
