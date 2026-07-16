import {
  requireNativeComponent,
  type HostComponent,
  type NativeSyntheticEvent,
  type TextInputFocusEventData,
  type TextInputSubmitEditingEventData,
  type ViewProps,
} from 'react-native';
import type { AppTextInputNativeEvent, AppTextInputSelection } from '../types';

export interface NativeAppTextInputProps extends ViewProps {
  text: string;
  entities: string;
  revision: number;
  selection: AppTextInputSelection;
  placeholder?: string;
  placeholderTextColor?: number;
  multiline?: boolean;
  editable?: boolean;
  autoFocus?: boolean;
  selectionColor?: number;
  keyboardType?: string;
  returnKeyType?: string;
  secureTextEntry?: boolean;
  numberOfLines?: number;
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
  maximumAnimatedEmojiCount?: number;
  animatedEmojiSize?: number;
  animatedEmojiVerticalOffset?: number;
  color?: number;
  fontSize?: number;
  animationSources?: Record<string, Record<string, unknown>>;
  onAppTextInputChange?: (event: NativeSyntheticEvent<AppTextInputNativeEvent>) => void;
  onSelectionChangeNative?: (
    event: NativeSyntheticEvent<{ selection: AppTextInputSelection }>
  ) => void;
  onFocus?: (event: NativeSyntheticEvent<TextInputFocusEventData>) => void;
  onBlur?: (event: NativeSyntheticEvent<TextInputFocusEventData>) => void;
  onSubmitEditing?: (event: NativeSyntheticEvent<TextInputSubmitEditingEventData>) => void;
  onShortcodeQueryChange?: (
    event: NativeSyntheticEvent<{
      query?: string | null;
      start: number;
      end: number;
    }>
  ) => void;
}

export default requireNativeComponent<NativeAppTextInputProps>(
  'AppTextInput'
) as HostComponent<NativeAppTextInputProps>;
