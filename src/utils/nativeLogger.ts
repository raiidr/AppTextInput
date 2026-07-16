import { NativeEventEmitter, NativeModules } from 'react-native';

const AppTextInputLogger = NativeModules.AppTextInputLogger;

/**
 * Event emitter for native AppTextInput debug logs. Subscribers receive log
 * messages emitted from Swift/Objective-C in DEBUG builds.
 */
export const appTextInputLoggerEmitter = AppTextInputLogger
  ? new NativeEventEmitter(AppTextInputLogger)
  : null;

let nativeLogSubscription: (() => void) | null = null;

/**
 * Subscribes to native AppTextInput logs and forwards them to the JavaScript
 * console. No-op in production or when the native module is unavailable.
 * Calling this multiple times is safe; only one subscription is kept.
 */
export function subscribeToNativeLogs(): (() => void) | null {
  if (!__DEV__ || !appTextInputLoggerEmitter) {
    return null;
  }

  if (nativeLogSubscription != null) {
    return nativeLogSubscription;
  }

  const subscription = appTextInputLoggerEmitter.addListener(
    'onAppTextInputLog',
    (event: { level?: string; message?: string; timestamp?: number }) => {
      const level = event?.level ?? 'info';
      const message = event?.message ?? '';
      // eslint-disable-next-line no-console
      console.log(`[Native AppTextInput ${level}] ${message}`);
    }
  );

  nativeLogSubscription = () => {
    subscription.remove();
    nativeLogSubscription = null;
  };

  return nativeLogSubscription;
}
