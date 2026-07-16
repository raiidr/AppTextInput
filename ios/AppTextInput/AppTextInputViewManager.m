#import "AppTextInputViewManager.h"

#import <React/RCTLog.h>
#import <React/RCTUIManager.h>
#import <React/RCTViewManager.h>
#import <React/UIView+React.h>

#if __has_include(<AppTextInput/AppTextInput-Swift.h>)
  #import <AppTextInput/AppTextInput-Swift.h>
#else
  #import "AppTextInput-Swift.h"
#endif

@implementation AppTextInputViewManager

RCT_EXPORT_MODULE(AppTextInput)

- (UIView *)view {
  return [[AppTextInputView alloc] init];
}

// MARK: - View properties

RCT_CUSTOM_VIEW_PROPERTY(text, NSString, AppTextInputView) {
  [view setText:json];
}

RCT_CUSTOM_VIEW_PROPERTY(entities, NSString, AppTextInputView) {
  [view setEntities:json];
}

RCT_CUSTOM_VIEW_PROPERTY(revision, NSNumber, AppTextInputView) {
  [view setRevision:[json intValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(selection, NSDictionary, AppTextInputView) {
  NSDictionary *selection = json;
  [view setSelection:selection];
}

RCT_CUSTOM_VIEW_PROPERTY(placeholder, NSString, AppTextInputView) {
  [view setPlaceholder:json];
}

RCT_CUSTOM_VIEW_PROPERTY(placeholderTextColor, NSNumber, AppTextInputView) {
  [view setPlaceholderTextColor:[RCTConvert UIColor:json]];
}

RCT_CUSTOM_VIEW_PROPERTY(multiline, BOOL, AppTextInputView) {
  [view setMultiline:[json boolValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(editable, BOOL, AppTextInputView) {
  [view setEditable:[json boolValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(autoFocus, BOOL, AppTextInputView) {
  [view setAutoFocus:[json boolValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(selectionColor, NSNumber, AppTextInputView) {
  [view setSelectionColor:[RCTConvert UIColor:json]];
}

RCT_CUSTOM_VIEW_PROPERTY(color, UIColor, AppTextInputView) {
  [view setColor:[RCTConvert UIColor:json]];
}

RCT_CUSTOM_VIEW_PROPERTY(fontSize, NSNumber, AppTextInputView) {
  [view setFontSize:json];
}

RCT_CUSTOM_VIEW_PROPERTY(keyboardType, NSString, AppTextInputView) {
  [view setKeyboardType:json];
}

RCT_CUSTOM_VIEW_PROPERTY(returnKeyType, NSString, AppTextInputView) {
  [view setReturnKeyType:json];
}

RCT_CUSTOM_VIEW_PROPERTY(secureTextEntry, BOOL, AppTextInputView) {
  [view setSecureTextEntry:[json boolValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(numberOfLines, NSNumber, AppTextInputView) {
  [view setNumberOfLines:[json intValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(textAlign, NSString, AppTextInputView) {
  [view setTextAlign:json];
}

RCT_CUSTOM_VIEW_PROPERTY(autoCapitalize, NSString, AppTextInputView) {
  [view setAutoCapitalize:json];
}

RCT_CUSTOM_VIEW_PROPERTY(autoCorrect, BOOL, AppTextInputView) {
  [view setAutoCorrect:[json boolValue]];
}

RCT_CUSTOM_VIEW_PROPERTY(autoComplete, NSString, AppTextInputView) {
  [view setAutoComplete:json];
}

RCT_CUSTOM_VIEW_PROPERTY(textContentType, NSString, AppTextInputView) {
  [view setTextContentType:json];
}

RCT_CUSTOM_VIEW_PROPERTY(submitBehavior, NSString, AppTextInputView) {
  [view setSubmitBehavior:json];
}

RCT_CUSTOM_VIEW_PROPERTY(enableAnimatedEmoji, BOOL, AppTextInputView) {
  // Reserved for future native shortcode handling.
}

RCT_CUSTOM_VIEW_PROPERTY(animateWhileBlurred, BOOL, AppTextInputView) {
  // Reserved for animation lifecycle control.
}

RCT_CUSTOM_VIEW_PROPERTY(respectReducedMotion, BOOL, AppTextInputView) {
  // Handled automatically by checking UIAccessibility.isReduceMotionEnabled.
}

RCT_CUSTOM_VIEW_PROPERTY(maximumAnimatedEmojiCount, NSNumber, AppTextInputView) {
  // Reserved for future native enforcement.
}

RCT_CUSTOM_VIEW_PROPERTY(animatedEmojiSize, NSNumber, AppTextInputView) {
  // Reserved for future size override support.
}

RCT_CUSTOM_VIEW_PROPERTY(animatedEmojiVerticalOffset, NSNumber, AppTextInputView) {
  // Reserved for future baseline offset support.
}

RCT_CUSTOM_VIEW_PROPERTY(animationSources, NSDictionary, AppTextInputView) {
  RCTLogInfo(@"[AppTextInputViewManager] set animationSources prop (json=%@)", json);
  [view setAnimationSources:json ?: @{}];
}

RCT_EXPORT_VIEW_PROPERTY(onAppTextInputChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onSelectionChangeNative, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onFocus, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onBlur, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onSubmitEditing, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShortcodeQueryChange, RCTDirectEventBlock)

// MARK: - Commands

RCT_EXPORT_METHOD(focus:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      [view focus];
    }
  }];
}

RCT_EXPORT_METHOD(blur:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      [view blur];
    }
  }];
}

RCT_EXPORT_METHOD(clear:(nonnull NSNumber *)reactTag) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      [view clear];
    }
  }];
}

RCT_EXPORT_METHOD(setSelection:(nonnull NSNumber *)reactTag start:(nonnull NSNumber *)start end:(nonnull NSNumber *)end) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      [view setSelectionCommand:[start intValue] end:[end intValue]];
    }
  }];
}

RCT_EXPORT_METHOD(insertAnimatedEmoji:(nonnull NSNumber *)reactTag
                  id:(nonnull NSString *)emojiId
                  shortcode:(nonnull NSString *)shortcode
                  fallback:(nonnull NSString *)fallback
                  assetKey:(nonnull NSString *)assetKey
                  start:(nonnull NSNumber *)start
                  end:(nonnull NSNumber *)end) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      [view insertAnimatedEmoji:emojiId shortcode:shortcode fallback:fallback assetKey:assetKey start:[start intValue] end:[end intValue]];
    }
  }];
}

RCT_EXPORT_METHOD(replaceRange:(nonnull NSNumber *)reactTag
                  start:(nonnull NSNumber *)start
                  length:(nonnull NSNumber *)length
                  text:(nonnull NSString *)text
                  entitiesJson:(nonnull NSString *)entitiesJson) {
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    AppTextInputView *view = viewRegistry[reactTag];
    if ([view isKindOfClass:[AppTextInputView class]]) {
      NSRange range = NSMakeRange([start intValue], [length intValue]);
      [view replaceRangeCommand:range text:text entitiesJson:entitiesJson];
    }
  }];
}

@end
