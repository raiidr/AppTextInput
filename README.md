# @app/app-text-input

A React Native `TextInput`-compatible component that supports inline animated Lottie emoji as atomic text entities. Animated emoji are loaded from a remote server catalog and passed to the native layer as Lottie JSON sources.

## Current status

This package is under active development. The following parts are implemented and tested:

- Package scaffolding for Android, iOS, and TypeScript.
- Public TypeScript API (`AppTextInput`, `AppTextInputValue`, `AnimatedEmojiEntity`, etc.).
- Internal document model with UTF-16 offsets and object replacement characters (`\uFFFC`).
- Shortcode parser (`:rainbow:` → animated entity).
- Document conversion utilities (shortcode fallback, Unicode fallback, message API payload).
- Server-driven animated emoji utilities (`loadAnimationSources`, `buildAnimatedEmojiRegistry`).
- 34 unit tests covering the document model and parser.

The native Android and iOS implementations are currently skeletons. The JavaScript fallback uses a standard `TextInput` with shortcode fallback text so the component can be imported and exercised immediately while the native rendering is being built.

## Installation

1. Add the local package to the root `package.json`:

   ```json
   "@app/app-text-input": "file:packages/app-text-input"
   ```

2. Run `npm install` from the root.
3. Re-run `pod install` on iOS and rebuild Android.

## Usage

Animated emoji are **server-driven**. Your backend provides a catalog of items, each with a remote Lottie JSON URL. The package fetches those URLs and passes the parsed JSON to the native component via the `animationSources` prop.

```tsx
import { useEffect, useState } from 'react';
import {
  AppTextInput,
  buildAnimatedEmojiRegistry,
  loadAnimationSources,
  type AnimatedEmojiCatalogItem,
} from '@app/app-text-input';

const catalog: AnimatedEmojiCatalogItem[] = [
  {
    id: 'rainbow',
    shortcode: ':rainbow:',
    fallback: '🌈',
    animationUrl: 'https://your-cdn.app/animated-emoji/rainbow.json',
  },
];

function Composer() {
  const [value, setValue] = useState({ text: '', entities: [] });
  const [animationSources, setAnimationSources] = useState({});
  const registry = buildAnimatedEmojiRegistry(catalog);

  useEffect(() => {
    loadAnimationSources(catalog).then(setAnimationSources);
  }, []);

  return (
    <AppTextInput
      value={value}
      onChange={setValue}
      animatedEmojiRegistry={registry}
      animationSources={animationSources}
      multiline
      placeholder="Message"
    />
  );
}
```

### Backward compatibility

For consumers that already build a registry manually, the `assetKey` field still stores the animation URL. The native layer prefers `animationSources[id]` when available and falls back to treating `assetKey` as a remote URL.

## Limitations

- The current JavaScript fallback does not render inline Lottie animations. It displays the shortcode fallback text (`:rainbow:`) in a regular `TextInput` and parses shortcodes as you type.
- The native Android and iOS modules must be completed before the package meets the version 1 release criteria in `IMPORTANT.md`.

## Development

```bash
cd packages/app-text-input
npm run typecheck
npx jest --config jest.config.js
```
