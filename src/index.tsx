export { AppTextInput } from './components/AppTextInput';
export type {
  AnimatedEmojiCatalogItem,
  AnimatedEmojiDefinition,
  AnimatedEmojiEntity,
  AnimatedEmojiRegistry,
  AnimatedEmojiSource,
  AnimatedEmojiSources,
  AnimatedEmojiInsertEvent,
  AnimatedEmojiRemoveEvent,
  AppTextEntity,
  AppTextInputChangeEvent,
  AppTextInputNativeEvent,
  AppTextInputProps,
  AppTextInputRef,
  AppTextInputSelection,
  AppTextInputValue,
  ShortcodeParserConfig,
  ShortcodeQuery,
  TextRange,
} from './types';

export { OBJECT_REPLACEMENT_CHARACTER } from './types';

export {
  createAnimatedEmojiEntity,
  createDocument,
  documentToMessageApiPayload,
  documentToNativeText,
  documentToShortcodeFallback,
  documentToUnicodeFallback,
  documentToValue,
  findEntityAtOffset,
  nativeTextToDocument,
  normalizeEntities,
  normalizeSelection,
  shortcodeFallbackToDocument,
  valueToDocument,
  validateDocument,
  type AppTextDocument,
  type MessageApiPayload,
} from './utils/document';

export {
  findActiveShortcode,
  findAnimatedEmojiDefinition,
  findCompletedShortcodeAtCaret,
  findCompletedShortcodeAtEnd,
  getShortcodeSuggestions,
  parsePastedText,
  replaceCompletedShortcode,
  resolveParserConfig,
  shouldCancelShortcode,
} from './utils/parser';

export {
  buildAnimatedEmojiRegistry,
  clearAssetCache,
  loadAnimationSources,
  preloadAnimatedEmojiAssets,
  type LoadAnimationSourcesOptions,
} from './utils/assets';
