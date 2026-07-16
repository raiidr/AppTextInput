# Patches and Differences from React Native

This document lists intentional deviations from the upstream React Native implementation.

1. **Custom document model**  
   React Native stores text as a plain string. This package stores a separate entity list and uses `\uFFFC` as an object replacement character for animated emoji.

2. **Animated emoji spans**  
   React Native `TextInput` does not support inline `ReplacementSpan` (Android) or `NSTextAttachment` (iOS) for editable text. This package adds custom spans to render Lottie animations inline.

3. **Shortcode parsing**  
   The package intercepts text changes to detect `:shortcode:` tokens and replace them with atomic entities. This is not part of the upstream `TextInput` pipeline.

4. **Selection normalization**  
   Selections are normalized so that the cursor can never land inside an animated entity. This ensures atomic insertion and deletion behavior.

5. **Lottie dependencies**  
   The package adds `com.airbnb.android:lottie` (Android) and `lottie-ios` (iOS) as direct dependencies, which are not part of React Native.
