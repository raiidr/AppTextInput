import type {
  BubblingEventHandler,
  DirectEventHandler,
  Double,
  Int32,
  UnsafeMixed,
} from 'react-native/Libraries/Types/CodegenTypes';
import * as React from 'react';
import type { HostComponent, ViewProps } from 'react-native';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';

export type AppTextInputEntity = {
  type: string;
  id: string;
  shortcode: string;
  fallback: string;
  assetKey: string;
  offset: Int32;
  length: Int32;
};

export type AppTextInputSelection = {
  start: Int32;
  end: Int32;
};

export type AppTextInputSelectionChangeEvent = {
  selection: {
    start: Int32;
    end: Int32;
  };
};

type AppTextInputFocusEvent = {
  text?: string;
  eventCount?: Int32;
};

type AppTextInputSubmitEditingEvent = {
  text?: string;
  eventCount?: Int32;
};

export type AppTextInputChangeEvent = {
  text: string;
  entities: string;
  revision: Int32;
  selection: {
    start: Int32;
    end: Int32;
  };
};

export type AppTextInputShortcodeQueryEvent = {
  query?: string;
  start: Int32;
  end: Int32;
};

export interface AppTextInputNativeProps extends ViewProps {
  text: string;
  entities: string;
  revision: Int32;
  selection: AppTextInputSelection;
  placeholder?: string;
  placeholderTextColor?: Double;
  multiline?: boolean;
  editable?: boolean;
  autoFocus?: boolean;
  selectionColor?: Double;
  keyboardType?: string;
  returnKeyType?: string;
  secureTextEntry?: boolean;
  numberOfLines?: Int32;
  textAlign?: string;
  autoCapitalize?: string;
  autoCorrect?: boolean;
  autoComplete?: string;
  textContentType?: string;
  submitBehavior?: string;
  enableAnimatedEmoji?: boolean;
  animateWhileBlurred?: boolean;
  respectReducedMotion?: boolean;
  shortcodeTrigger?: string;
  maximumAnimatedEmojiCount?: Int32;
  animatedEmojiSize?: Double;
  animatedEmojiVerticalOffset?: Double;
  color?: Double;
  fontSize?: Double;
  animationSources?: UnsafeMixed;
  onAppTextInputChange?: BubblingEventHandler<AppTextInputChangeEvent>;
  onSelectionChangeNative?: DirectEventHandler<AppTextInputSelectionChangeEvent>;
  onFocus?: BubblingEventHandler<AppTextInputFocusEvent>;
  onBlur?: BubblingEventHandler<AppTextInputFocusEvent>;
  onSubmitEditing?: BubblingEventHandler<AppTextInputSubmitEditingEvent>;
  onShortcodeQueryChange?: DirectEventHandler<AppTextInputShortcodeQueryEvent>;
}

export interface NativeCommands {
  focus: (viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>) => void;
  blur: (viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>) => void;
  clear: (viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>) => void;
  setSelection: (
    viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>,
    start: Int32,
    end: Int32
  ) => void;
  insertAnimatedEmoji: (
    viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>,
    id: string,
    shortcode: string,
    fallback: string,
    assetKey: string,
    start: Int32,
    end: Int32
  ) => void;
  replaceRange: (
    viewRef: React.ElementRef<HostComponent<AppTextInputNativeProps>>,
    start: Int32,
    length: Int32,
    text: string,
    entitiesJson: string
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'focus',
    'blur',
    'clear',
    'setSelection',
    'insertAnimatedEmoji',
    'replaceRange',
  ],
});

export default codegenNativeComponent<AppTextInputNativeProps>(
  'AppTextInput'
) as HostComponent<AppTextInputNativeProps>;
