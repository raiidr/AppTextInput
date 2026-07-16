import React, {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
  type ForwardRefRenderFunction,
} from 'react';
import {
  Platform,
  StyleSheet,
  TextInput,
  UIManager,
  findNodeHandle,
  processColor,
  type ColorValue,
  type NativeSyntheticEvent,
  type TextInputFocusEventData,
  type TextInputSelectionChangeEventData,
  type TextInputSubmitEditingEventData,
  type TextStyle,
} from 'react-native';

import {
  OBJECT_REPLACEMENT_CHARACTER,
  type AnimatedEmojiDefinition,
  type AnimatedEmojiRegistry,
  type AppTextInputProps,
  type AppTextInputRef,
  type AppTextInputSelection,
  type AppTextInputValue,
  type ShortcodeQuery,
  type TextRange,
} from '../types';
import {
  createAnimatedEmojiEntity,
  createDocument,
  documentToShortcodeFallback,
  documentToUnicodeFallback,
  documentToValue,
  normalizeSelection,
  replaceRangeInDocument,
  valueToDocument,
} from '../utils/document';
import {
  findActiveShortcode,
  findAnimatedEmojiDefinition,
  findCompletedShortcodeAtCaret,
  parsePastedText,
} from '../utils/parser';
import NativeAppTextInput from '../spec/NativeAppTextInput';
import { subscribeToNativeLogs } from '../utils/nativeLogger';

const DEFAULT_MAX_EMOJI_COUNT = 50;

const nativeCommandNames = [
  'focus',
  'blur',
  'clear',
  'setSelection',
  'insertAnimatedEmoji',
  'replaceRange',
] as const;

type NativeCommandName = (typeof nativeCommandNames)[number];

function getDefaultValue(props: AppTextInputProps): AppTextInputValue {
  return props.value ?? props.defaultValue ?? { text: '', entities: [] };
}

function isNativeComponentAvailable(): boolean {
  // Native rendering is currently implemented only on iOS. Android will fall
  // back to the TextInput implementation until the Android native layer is built.
  if (Platform.OS !== 'ios') {
    return false;
  }
  return UIManager.getViewManagerConfig?.('AppTextInput') != null;
}

function dispatchNativeCommand(
  ref: React.RefObject<any>,
  command: NativeCommandName,
  args: unknown[]
): void {
  if (ref.current == null) {
    return;
  }
  const nodeHandle = findNodeHandle(ref.current);
  if (nodeHandle == null) {
    return;
  }
  UIManager.dispatchViewManagerCommand(nodeHandle, command, args);
}

function colorToNumber(color: ColorValue | undefined): number | undefined {
  const processed = processColor(color);
  return typeof processed === 'number' ? processed : undefined;
}

const AppTextInputImpl: ForwardRefRenderFunction<AppTextInputRef, AppTextInputProps> = (
  props,
  ref
) => {
  const {
    value,
    defaultValue,
    onChange,
    onChangeText,
    onSelectionChange,
    onFocus,
    onBlur,
    onSubmitEditing,
    onAnimatedEmojiInsert,
    onAnimatedEmojiRemove,
    onShortcodeQueryChange,
    animatedEmojiRegistry = {},
    animationSources,
    preloadAnimationSource,
    enableAnimatedEmoji = true,
    maximumAnimatedEmojiCount = DEFAULT_MAX_EMOJI_COUNT,
    shortcodeTrigger = ':',
    multiline,
    placeholder,
    placeholderTextColor,
    style,
    editable,
    autoFocus,
    selection,
    selectionColor,
    keyboardType,
    returnKeyType,
    secureTextEntry,
    numberOfLines,
    textAlign,
    autoCapitalize,
    autoCorrect,
    autoComplete,
    spellCheck,
    textContentType,
    submitBehavior,
    animateWhileBlurred,
    respectReducedMotion,
    animatedEmojiSize,
    animatedEmojiVerticalOffset,
  } = props;

  // Extract text styling from the style prop so the native layer can apply the
  // same color and font size as the React Native TextInput fallback path. Without
  // this, text can become invisible on custom backgrounds (e.g. white text on a
  // dark green composer) and emoji attachments use the wrong baseline size.
  const { color: textColor, fontSize: textFontSize } = useMemo(() => {
    const flattened = StyleSheet.flatten(style) as TextStyle | undefined;
    return {
      color: flattened?.color,
      fontSize: flattened?.fontSize,
    };
  }, [style]);

  const isControlled = value !== undefined;
  const inputRef = useRef<TextInput>(null);
  const nativeRef = useRef<React.ElementRef<typeof NativeAppTextInput> | null>(null);
  const useNative = isNativeComponentAvailable();

  const [internalValue, setInternalValue] = useState<AppTextInputValue>(
    getDefaultValue(props)
  );
  const [internalSelection, setInternalSelection] = useState<AppTextInputSelection>(
    selection
      ? { start: selection.start, end: selection.end ?? selection.start }
      : { start: 0, end: 0 }
  );
  const [isFocused, setIsFocused] = useState(false);

  // Forward native iOS AppTextInput logs to the JavaScript console in debug
  // builds. This is a no-op in production and on Android.
  useEffect(() => {
    return subscribeToNativeLogs() ?? undefined;
  }, []);

  const currentValue = isControlled ? value : internalValue;
  const document = useMemo(() => valueToDocument(currentValue), [currentValue]);
  const displayText = useMemo(
    () => documentToUnicodeFallback(document, animatedEmojiRegistry),
    [document, animatedEmojiRegistry]
  );

  const shortcodeConfig = useMemo(
    () => ({ trigger: shortcodeTrigger }),
    [shortcodeTrigger]
  );

  const emitChange = useCallback(
    (nextDocument: import('../utils/document').AppTextDocument) => {
      const nextValue = documentToValue(nextDocument);

      if (!isControlled) {
        setInternalValue(nextValue);
      }

      onChange?.(nextValue);
      // Consumers like Chat.jsx store the plain string in React state and later
      // feed it back through shortcodeFallbackToDocument. Emit the shortcode
      // fallback text (e.g. ":rainbow:") rather than the raw document text
      // containing the object replacement character.
      const fallbackText = documentToShortcodeFallback(nextDocument, animatedEmojiRegistry);
      if (__DEV__) {
        console.log('AppTextInput emitChange', {
          rawText: nextDocument.text,
          fallbackText,
          entityCount: nextDocument.entities.length,
        });
      }
      onChangeText?.(fallbackText);
    },
    [isControlled, onChange, onChangeText, animatedEmojiRegistry]
  );

  const emitEntityDiff = useCallback(
    (
      previousEntities: import('../types').AppTextEntity[],
      nextEntities: import('../types').AppTextEntity[]
    ) => {
      const previousIds = new Set(previousEntities.map((e) => e.id + ':' + e.offset));
      const nextIds = new Set(nextEntities.map((e) => e.id + ':' + e.offset));

      for (const entity of nextEntities) {
        const key = entity.id + ':' + entity.offset;
        if (!previousIds.has(key)) {
          onAnimatedEmojiInsert?.({
            entity,
            range: { start: entity.offset, end: entity.offset + 1 },
          });
        }
      }

      for (const entity of previousEntities) {
        const key = entity.id + ':' + entity.offset;
        if (!nextIds.has(key)) {
          onAnimatedEmojiRemove?.({
            entity,
            range: { start: entity.offset, end: entity.offset + 1 },
          });
        }
      }
    },
    [onAnimatedEmojiInsert, onAnimatedEmojiRemove]
  );

  const updateActiveShortcode = useCallback(
    (text: string, caret: number) => {
      if (!enableAnimatedEmoji) {
        onShortcodeQueryChange?.(null);
        return;
      }

      const active = findActiveShortcode(text, caret, shortcodeConfig);
      // Start preloading the Lottie source for the active shortcode so the
      // animated emoji is ready when the user finishes typing the shortcode.
      if (active) {
        const definition = findAnimatedEmojiDefinition(
          animatedEmojiRegistry,
          active.text,
          shortcodeConfig
        );
        if (definition) {
          preloadAnimationSource?.(definition.id).catch(() => {});
        }
      }
      onShortcodeQueryChange?.(active);
    },
    [enableAnimatedEmoji, onShortcodeQueryChange, shortcodeConfig, animatedEmojiRegistry, preloadAnimationSource]
  );

  const handleChangeText = useCallback(
    (text: string) => {
      const caret = internalSelection.start ?? text.length;

      let nextDoc: import('../utils/document').AppTextDocument;

      if (enableAnimatedEmoji) {
        const parsed = parsePastedText(text, animatedEmojiRegistry, shortcodeConfig);
        const cappedEntities = parsed.entities.slice(0, maximumAnimatedEmojiCount);
        nextDoc = createDocument(parsed.text, cappedEntities, document.revision + 1);
        emitEntityDiff(document.entities, cappedEntities);
      } else {
        nextDoc = createDocument(text, [], document.revision + 1);
      }

      emitChange(nextDoc);
      updateActiveShortcode(nextDoc.text, Math.min(caret, nextDoc.text.length));
    },
    [
      document.entities,
      document.revision,
      enableAnimatedEmoji,
      internalSelection,
      animatedEmojiRegistry,
      shortcodeConfig,
      maximumAnimatedEmojiCount,
      emitChange,
      updateActiveShortcode,
      emitEntityDiff,
    ]
  );

  const handleSelectionChange = useCallback(
    (event: NativeSyntheticEvent<TextInputSelectionChangeEventData>) => {
      const { start, end } = event.nativeEvent.selection;
      const selection = { start, end };
      setInternalSelection(selection);
      onSelectionChange?.(event);
      updateActiveShortcode(displayText, start);
    },
    [displayText, onSelectionChange, updateActiveShortcode]
  );

  const handleFocus = useCallback(
    (event: NativeSyntheticEvent<TextInputFocusEventData>) => {
      setIsFocused(true);
      onFocus?.(event);
    },
    [onFocus]
  );

  const handleBlur = useCallback(
    (event: NativeSyntheticEvent<TextInputFocusEventData>) => {
      setIsFocused(false);
      onBlur?.(event);
    },
    [onBlur]
  );

  const handleSubmitEditing = useCallback(
    (event: NativeSyntheticEvent<TextInputSubmitEditingEventData>) => {
      onSubmitEditing?.(event);
    },
    [onSubmitEditing]
  );

  // MARK: - Native event handlers

  const handleNativeChange = useCallback(
    (event: NativeSyntheticEvent<import('../types').AppTextInputNativeEvent>) => {
      const { text, entities, revision, selection: nativeSelection } = event.nativeEvent;
      let parsedEntities: import('../types').AppTextEntity[] = [];
      try {
        parsedEntities = JSON.parse(entities) as import('../types').AppTextEntity[];
      } catch {
        parsedEntities = [];
      }

      let nextDoc = createDocument(text, parsedEntities, revision);
      let nextSelection = nativeSelection;

      if (enableAnimatedEmoji) {
        const caret = Math.max(0, Math.min(nativeSelection.start, text.length));
        const completed = findCompletedShortcodeAtCaret(text, caret, shortcodeConfig);
        if (completed) {
          const definition = findAnimatedEmojiDefinition(
            animatedEmojiRegistry,
            completed.shortcode,
            shortcodeConfig
          );
          const emojiCount = parsedEntities.filter(
            (entity) => entity.type === 'animated-emoji'
          ).length;
          if (definition && emojiCount < maximumAnimatedEmojiCount) {
            const entity = createAnimatedEmojiEntity(
              definition,
              completed.range.start
            );
            nextDoc = replaceRangeInDocument(
              nextDoc,
              completed.range,
              OBJECT_REPLACEMENT_CHARACTER,
              [entity]
            );
            // If the shortcode was completed just before a separator (e.g. a
            // space or comma), keep the separator and place the cursor after
            // it. The native replaceRange command only knows about the entity
            // range, so we must explicitly move the cursor for the separator
            // case.
            const isSeparatorCase = completed.range.end < caret;
            const cursorOffset = 1 + (isSeparatorCase ? caret - completed.range.end : 0);
            nextSelection = {
              start: completed.range.start + cursorOffset,
              end: completed.range.start + cursorOffset,
            };
            dispatchNativeCommand(nativeRef, 'replaceRange', [
              completed.range.start,
              completed.range.end - completed.range.start,
              OBJECT_REPLACEMENT_CHARACTER,
              JSON.stringify([{ ...entity, offset: 0 }]),
            ]);
            if (isSeparatorCase) {
              dispatchNativeCommand(nativeRef, 'setSelection', [
                nextSelection.start,
                nextSelection.end,
              ]);
            }
          }
        }
      }

      emitEntityDiff(document.entities, nextDoc.entities);
      emitChange(nextDoc);
      setInternalSelection(nextSelection);
      updateActiveShortcode(
        nextDoc.text,
        Math.min(nextSelection.start, nextDoc.text.length)
      );
    },
    [
      document.entities,
      emitChange,
      emitEntityDiff,
      updateActiveShortcode,
      enableAnimatedEmoji,
      animatedEmojiRegistry,
      shortcodeConfig,
      maximumAnimatedEmojiCount,
    ]
  );

  const handleNativeSelectionChange = useCallback(
    (
      event: NativeSyntheticEvent<{
        selection: import('../types').AppTextInputSelection;
      }>
    ) => {
      const nativeSelection = event.nativeEvent.selection;
      setInternalSelection(nativeSelection);
      onSelectionChange?.(
        event as unknown as NativeSyntheticEvent<TextInputSelectionChangeEventData>
      );
      updateActiveShortcode(document.text, nativeSelection.start);
    },
    [document.text, onSelectionChange, updateActiveShortcode]
  );

  const handleNativeFocus = useCallback(
    (event: NativeSyntheticEvent<TextInputFocusEventData>) => {
      setIsFocused(true);
      onFocus?.(event);
    },
    [onFocus]
  );

  const handleNativeBlur = useCallback(
    (event: NativeSyntheticEvent<TextInputFocusEventData>) => {
      setIsFocused(false);
      onBlur?.(event);
    },
    [onBlur]
  );

  const handleNativeSubmitEditing = useCallback(
    (event: NativeSyntheticEvent<TextInputSubmitEditingEventData>) => {
      onSubmitEditing?.(event);
    },
    [onSubmitEditing]
  );

  const handleNativeShortcodeQueryChange = useCallback(
    (
      event: NativeSyntheticEvent<{
        query?: string | null;
        start: number;
        end: number;
      }>
    ) => {
      const { query, start, end } = event.nativeEvent;
      if (query == null || typeof query !== 'string') {
        onShortcodeQueryChange?.(null);
        return;
      }
      onShortcodeQueryChange?.({ text: query, range: { start, end } });
    },
    [onShortcodeQueryChange]
  );

  useEffect(() => {
    if (isControlled && value) {
      setInternalValue(value);
    }
  }, [isControlled, value]);

  useEffect(() => {
    if (selection) {
      setInternalSelection({
        start: selection.start,
        end: selection.end ?? selection.start,
      });
    }
  }, [selection]);

  useImperativeHandle(
    ref,
    (): AppTextInputRef => ({
      focus: () => {
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'focus', []);
        } else {
          inputRef.current?.focus();
        }
      },
      blur: () => {
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'blur', []);
        } else {
          inputRef.current?.blur();
        }
      },
      clear: () => {
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'clear', []);
        } else {
          const nextDoc = createDocument('', [], document.revision + 1);
          emitChange(nextDoc);
          setInternalSelection({ start: 0, end: 0 });
        }
      },
      isFocused: () => isFocused,
      setSelection: (start, end) => {
        const safeEnd = end ?? start;
        const normalized = normalizeSelection(document, { start, end: safeEnd });
        setInternalSelection({
          start: normalized.start,
          end: normalized.end,
        });
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'setSelection', [normalized.start, normalized.end]);
        } else {
          inputRef.current?.setNativeProps({
            selection: { start: normalized.start, end: normalized.end },
          });
        }
      },
      insertAnimatedEmoji: (emoji, range) => {
        const insertionRange = range ?? {
          start: internalSelection.start,
          end: internalSelection.end,
        };
        if (__DEV__) {
          console.log('AppTextInput insertAnimatedEmoji', {
            useNative,
            emoji,
            insertionRange,
          });
        }
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'insertAnimatedEmoji', [
            emoji.id,
            emoji.shortcode,
            emoji.fallback,
            emoji.assetKey,
            insertionRange.start,
            insertionRange.end,
          ]);
        } else {
          const nextDoc = replaceRangeInDocument(
            document,
            insertionRange,
            '\uFFFC',
            [
              {
                type: 'animated-emoji',
                id: emoji.id,
                shortcode: emoji.shortcode,
                fallback: emoji.fallback,
                assetKey: emoji.assetKey,
                offset: insertionRange.start,
                length: 1,
              },
            ]
          );
          emitChange(nextDoc);
          setInternalSelection({
            start: insertionRange.start + 1,
            end: insertionRange.start + 1,
          });
        }
      },
      replaceRange: (range, text, entities = []) => {
        if (useNative) {
          dispatchNativeCommand(nativeRef, 'replaceRange', [
            range.start,
            range.end - range.start,
            text,
            JSON.stringify(entities),
          ]);
        } else {
          const nextDoc = replaceRangeInDocument(document, range, text, entities);
          emitChange(nextDoc);
        }
      },
      getValue: () => documentToValue(document),
    }),
    [document, emitChange, internalSelection, isFocused, useNative]
  );

  const effectiveSelection = useMemo(
    () => normalizeSelection(document, internalSelection),
    [document, internalSelection]
  );

  const nativeProps = useMemo(
    () => ({
      ref: nativeRef,
      text: document.text,
      entities: JSON.stringify(document.entities),
      revision: document.revision,
      selection: effectiveSelection,
      placeholder,
      placeholderTextColor: colorToNumber(placeholderTextColor),
      multiline,
      editable,
      autoFocus,
      selectionColor: colorToNumber(selectionColor),
      keyboardType,
      returnKeyType,
      secureTextEntry,
      numberOfLines,
      textAlign,
      autoCapitalize,
      autoCorrect,
      autoComplete,
      textContentType,
      submitBehavior,
      enableAnimatedEmoji,
      animateWhileBlurred,
      respectReducedMotion,
      shortcodeTrigger,
      maximumAnimatedEmojiCount,
      animatedEmojiSize,
      animatedEmojiVerticalOffset,
      color: colorToNumber(textColor),
      fontSize: textFontSize,
      animationSources,
      onAppTextInputChange: handleNativeChange,
      onSelectionChangeNative: handleNativeSelectionChange,
      onFocus: handleNativeFocus as any,
      onBlur: handleNativeBlur as any,
      onSubmitEditing: handleNativeSubmitEditing as any,
      onShortcodeQueryChange: handleNativeShortcodeQueryChange,
      style,
    }),
    [
      document,
      effectiveSelection,
      placeholder,
      placeholderTextColor,
      multiline,
      editable,
      autoFocus,
      selectionColor,
      keyboardType,
      returnKeyType,
      secureTextEntry,
      numberOfLines,
      textAlign,
      autoCapitalize,
      autoCorrect,
      autoComplete,
      textContentType,
      submitBehavior,
      enableAnimatedEmoji,
      animateWhileBlurred,
      respectReducedMotion,
      shortcodeTrigger,
      maximumAnimatedEmojiCount,
      animatedEmojiSize,
      animatedEmojiVerticalOffset,
      textColor,
      textFontSize,
      animationSources,
      handleNativeChange,
      handleNativeSelectionChange,
      handleNativeFocus,
      handleNativeBlur,
      handleNativeSubmitEditing,
      handleNativeShortcodeQueryChange,
      style,
    ]
  );

  if (useNative) {
    return <NativeAppTextInput {...nativeProps} />;
  }

  return (
    <TextInput
      ref={inputRef}
      value={displayText}
      onChangeText={handleChangeText}
      onSelectionChange={handleSelectionChange}
      onFocus={handleFocus}
      onBlur={handleBlur}
      onSubmitEditing={handleSubmitEditing}
      selection={effectiveSelection}
      multiline={multiline}
      placeholder={placeholder}
      placeholderTextColor={placeholderTextColor}
      style={style}
      editable={editable}
      autoFocus={autoFocus}
      selectionColor={selectionColor}
      keyboardType={keyboardType}
      returnKeyType={returnKeyType}
      secureTextEntry={secureTextEntry}
      numberOfLines={numberOfLines}
      textAlign={textAlign}
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      autoComplete={autoComplete}
      spellCheck={spellCheck}
      textContentType={textContentType}
      submitBehavior={submitBehavior}
    />
  );
};

export const AppTextInput = forwardRef(AppTextInputImpl);

AppTextInput.displayName = 'AppTextInput';
