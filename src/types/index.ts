import type {
  NativeSyntheticEvent,
  TextInputFocusEventData,
  TextInputSelectionChangeEventData,
  TextInputSubmitEditingEventData,
  TextInputProps as RNTextInputProps,
  TextStyle,
} from 'react-native';

export const OBJECT_REPLACEMENT_CHARACTER = '\uFFFC';

export type AnimatedEmojiEntity = {
  type: 'animated-emoji';
  id: string;
  shortcode: string;
  fallback: string;
  assetKey: string;
  offset: number;
  length: 1;
};

export type AppTextEntity = AnimatedEmojiEntity;

export type AppTextInputValue = {
  text: string;
  entities: AppTextEntity[];
  revision?: number;
};

export type AnimatedEmojiDefinition = {
  id: string;
  shortcode: string;
  fallback: string;
  assetKey: string;
  /**
   * Remote URL for the Lottie animation JSON. When provided, the package fetches
   * the source and passes it to the native layer via `animationSources`.
   * This is the preferred way to load animated emoji in production.
   */
  animationUrl?: string;
  accessibilityLabel?: string;
};

export type AnimatedEmojiRegistry = Record<string, AnimatedEmojiDefinition>;

/**
 * Server catalog item representing a single animated emoji. Consumers fetch the
 * catalog from their backend and then use `loadAnimationSources` to build the
 * `animationSources` map expected by `AppTextInput`.
 */
export type AnimatedEmojiCatalogItem = {
  id: string;
  shortcode: string;
  fallback: string;
  animationUrl: string;
};

export type AnimatedEmojiSource = Record<string, unknown>;

export type AnimatedEmojiSources = Record<string, AnimatedEmojiSource>;

export type TextRange = {
  start: number;
  end: number;
};

export type ShortcodeParserConfig = {
  trigger?: string;
  allowedCharacters?: RegExp;
  maxLength?: number;
  caseSensitive?: boolean;
  replaceOnSpace?: boolean;
};

export type ShortcodeQuery = {
  text: string;
  range: TextRange;
} | null;

export type AppTextInputSelection = {
  start: number;
  end: number;
};

export type AppTextInputChangeEvent = {
  value: AppTextInputValue;
  selection: AppTextInputSelection;
};

export type AppTextInputNativeEvent = {
  text: string;
  entities: string;
  revision: number;
  selection: AppTextInputSelection;
};

export type AnimatedEmojiInsertEvent = {
  entity: AnimatedEmojiEntity;
  range: TextRange;
};

export type AnimatedEmojiRemoveEvent = {
  entity: AnimatedEmojiEntity;
  range: TextRange;
};

export type AppTextInputProps = Omit<
  RNTextInputProps,
  | 'value'
  | 'defaultValue'
  | 'onChange'
  | 'onChangeText'
  | 'onSelectionChange'
  | 'onFocus'
  | 'onBlur'
  | 'onSubmitEditing'
> & {
  value?: AppTextInputValue;
  defaultValue?: AppTextInputValue;
  onChange?: (value: AppTextInputValue) => void;
  onChangeText?: (text: string) => void;
  onSelectionChange?: (event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => void;
  onFocus?: (event: NativeSyntheticEvent<TextInputFocusEventData>) => void;
  onBlur?: (event: NativeSyntheticEvent<TextInputFocusEventData>) => void;
  onSubmitEditing?: (event: NativeSyntheticEvent<TextInputSubmitEditingEventData>) => void;
  onAnimatedEmojiInsert?: (event: AnimatedEmojiInsertEvent) => void;
  onAnimatedEmojiRemove?: (event: AnimatedEmojiRemoveEvent) => void;
  onShortcodeQueryChange?: (query: ShortcodeQuery) => void;
  animatedEmojiRegistry?: AnimatedEmojiRegistry;
  animationSources?: AnimatedEmojiSources;
  /**
   * Optional callback that the text input invokes when the user is typing a
   * known shortcode. Consumers can use this to preload the Lottie source so
   * the animated emoji is ready by the time the shortcode is completed,
   * avoiding a temporary fallback icon.
   */
  preloadAnimationSource?: (id: string) => Promise<void>;
  enableAnimatedEmoji?: boolean;
  animateWhileBlurred?: boolean;
  respectReducedMotion?: boolean;
  shortcodeTrigger?: string;
  maximumAnimatedEmojiCount?: number;
  animatedEmojiSize?: number;
  animatedEmojiVerticalOffset?: number;
  style?: TextStyle;
};

export type AppTextInputRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
  isFocused: () => boolean;
  setSelection: (start: number, end?: number) => void;
  insertAnimatedEmoji: (emoji: AnimatedEmojiDefinition, range?: TextRange) => void;
  replaceRange: (range: TextRange, text: string, entities?: AppTextEntity[]) => void;
  getValue: () => AppTextInputValue;
};
