#import "AppTextInputComponentView.h"

#import <React/RCTAssert.h>
#import <React/RCTConvert.h>
#import <React/RCTConversions.h>
#import <React/RCTFollyConvert.h>
#import <react/renderer/components/AppTextInput/AppTextInputComponentDescriptor.h>
#import <react/renderer/components/AppTextInput/AppTextInputProps.h>
#import <react/renderer/core/EventEmitter.h>

#if __has_include(<AppTextInput/AppTextInput-Swift.h>)
#import <AppTextInput/AppTextInput-Swift.h>
#else
#import "AppTextInput-Swift.h"
#endif

using namespace facebook::react;

static UIColor *_Nullable UIColorFromOptionalDouble(const std::optional<double> &color)
{
  if (!color.has_value()) {
    return nil;
  }
  return [RCTConvert UIColor:@((NSInteger)color.value())];
}

@implementation AppTextInputComponentView

// Force the Objective-C runtime to load this class even when the linker does not
// see a direct reference. Without +load, static frameworks built with -ObjC may
// still dead-strip the .o file, causing NSClassFromString(@"AppTextInputComponentView")
// to return nil and the Fabric component registration dictionary to crash.
// See: https://github.com/facebook/react-native/pull/37274
+ (void)load
{
  [super load];
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<AppTextInputComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const AppTextInputProps>();
    _props = defaultProps;

    AppTextInputView *view = [[AppTextInputView alloc] init];
    __weak __typeof(self) weakSelf = self;

    view.onAppTextInputChange = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"appTextInputChange" payload:payload];
    };
    view.onSelectionChangeNative = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"selectionChangeNative" payload:payload];
    };
    view.onFocus = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"focus" payload:payload];
    };
    view.onBlur = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"blur" payload:payload];
    };
    view.onSubmitEditing = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"submitEditing" payload:payload];
    };
    view.onShortcodeQueryChange = ^(NSDictionary *payload) {
      [weakSelf emitEvent:@"shortcodeQueryChange" payload:payload];
    };

    self.contentView = view;
  }

  return self;
}

- (void)emitEvent:(NSString *)eventName payload:(NSDictionary *)payload
{
  if (!_eventEmitter) {
    return;
  }

  _eventEmitter->dispatchEvent(
    std::string([eventName UTF8String]),
    convertIdToFollyDynamic(payload),
    RawEvent::Category::Unspecified
  );
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = static_cast<const AppTextInputProps &>(*props);
  const auto &previousProps = oldProps
    ? static_cast<const AppTextInputProps &>(*oldProps)
    : static_cast<const AppTextInputProps &>(*_props);

  AppTextInputView *view = (AppTextInputView *)self.contentView;

  // Required props
  if (newProps.text != previousProps.text) {
    [view setText:RCTNSStringFromString(newProps.text)];
  }

  if (newProps.entities != previousProps.entities) {
    [view setEntities:RCTNSStringFromString(newProps.entities)];
  }

  if (newProps.revision != previousProps.revision) {
    [view setRevision:newProps.revision];
  }

  if (newProps.selection.start != previousProps.selection.start ||
      newProps.selection.end != previousProps.selection.end) {
    [view setSelection:@{
      @"start": @(newProps.selection.start),
      @"end": @(newProps.selection.end),
    }];
  }

  // Optional string props
  if (newProps.placeholder != previousProps.placeholder) {
    [view setPlaceholder:RCTNSStringFromStringNilIfEmpty(newProps.placeholder.value_or(""))];
  }

  if (newProps.keyboardType != previousProps.keyboardType) {
    [view setKeyboardType:RCTNSStringFromStringNilIfEmpty(newProps.keyboardType.value_or(""))];
  }

  if (newProps.returnKeyType != previousProps.returnKeyType) {
    [view setReturnKeyType:RCTNSStringFromStringNilIfEmpty(newProps.returnKeyType.value_or(""))];
  }

  if (newProps.textAlign != previousProps.textAlign) {
    [view setTextAlign:RCTNSStringFromStringNilIfEmpty(newProps.textAlign.value_or(""))];
  }

  if (newProps.autoCapitalize != previousProps.autoCapitalize) {
    [view setAutoCapitalize:RCTNSStringFromStringNilIfEmpty(newProps.autoCapitalize.value_or(""))];
  }

  if (newProps.autoComplete != previousProps.autoComplete) {
    [view setAutoComplete:RCTNSStringFromStringNilIfEmpty(newProps.autoComplete.value_or(""))];
  }

  if (newProps.textContentType != previousProps.textContentType) {
    [view setTextContentType:RCTNSStringFromStringNilIfEmpty(newProps.textContentType.value_or(""))];
  }

  if (newProps.submitBehavior != previousProps.submitBehavior) {
    [view setSubmitBehavior:RCTNSStringFromStringNilIfEmpty(newProps.submitBehavior.value_or(""))];
  }

  // Optional bool props
  if (newProps.multiline != previousProps.multiline) {
    [view setMultiline:newProps.multiline.value_or(false)];
  }

  if (newProps.editable != previousProps.editable) {
    [view setEditable:newProps.editable.value_or(true)];
  }

  if (newProps.autoFocus != previousProps.autoFocus) {
    [view setAutoFocus:newProps.autoFocus.value_or(false)];
  }

  if (newProps.secureTextEntry != previousProps.secureTextEntry) {
    [view setSecureTextEntry:newProps.secureTextEntry.value_or(false)];
  }

  if (newProps.autoCorrect != previousProps.autoCorrect) {
    [view setAutoCorrect:newProps.autoCorrect.value_or(true)];
  }

  // Optional int props
  if (newProps.numberOfLines != previousProps.numberOfLines) {
    [view setNumberOfLines:newProps.numberOfLines.value_or(0)];
  }

  // Optional color props
  if (newProps.placeholderTextColor != previousProps.placeholderTextColor) {
    [view setPlaceholderTextColor:UIColorFromOptionalDouble(newProps.placeholderTextColor)];
  }

  if (newProps.selectionColor != previousProps.selectionColor) {
    [view setSelectionColor:UIColorFromOptionalDouble(newProps.selectionColor)];
  }

  if (newProps.color != previousProps.color) {
    [view setColor:UIColorFromOptionalDouble(newProps.color)];
  }

  // Optional double props
  if (newProps.fontSize != previousProps.fontSize) {
    [view setFontSize:newProps.fontSize.has_value() ? @(newProps.fontSize.value()) : nil];
  }

  // Optional unsafe object
  if (newProps.animationSources != previousProps.animationSources) {
    id sources = newProps.animationSources.has_value()
      ? convertFollyDynamicToId(newProps.animationSources.value())
      : nil;
    if (sources == [NSNull null]) {
      sources = nil;
    }
    [view setAnimationSources:(NSDictionary *)sources ?: @{}];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  AppTextInputView *view = (AppTextInputView *)self.contentView;

  if ([commandName isEqualToString:@"focus"]) {
    [view focus];
  } else if ([commandName isEqualToString:@"blur"]) {
    [view blur];
  } else if ([commandName isEqualToString:@"clear"]) {
    [view clear];
  } else if ([commandName isEqualToString:@"setSelection"]) {
    NSInteger start = [args[0] integerValue];
    NSInteger end = [args[1] integerValue];
    [view setSelectionCommand:start end:end];
  } else if ([commandName isEqualToString:@"insertAnimatedEmoji"]) {
    [view insertAnimatedEmoji:args[0]
                   shortcode:args[1]
                    fallback:args[2]
                     assetKey:args[3]
              animationSource:args[4]
                        start:[args[5] integerValue]
                          end:[args[6] integerValue]];
  } else if ([commandName isEqualToString:@"replaceRange"]) {
    NSInteger start = [args[0] integerValue];
    NSInteger length = [args[1] integerValue];
    [view replaceRangeCommand:NSMakeRange((NSUInteger)start, (NSUInteger)length)
                         text:args[2]
                   entitiesJson:args[3]];
  }
}

@end

#ifdef __cplusplus
extern "C" {
#endif

Class<RCTComponentViewProtocol> AppTextInputCls(void);

#ifdef __cplusplus
}
#endif

Class<RCTComponentViewProtocol> AppTextInputCls(void)
{
  return AppTextInputComponentView.class;
}
