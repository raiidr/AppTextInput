import type {
  AnimatedEmojiCatalogItem,
  AnimatedEmojiDefinition,
  AnimatedEmojiRegistry,
  AnimatedEmojiSources,
} from '../types';

const assetCache = new Map<string, Promise<unknown>>();

const isDevMode = (): boolean =>
  typeof __DEV__ !== 'undefined' && __DEV__ === true;

/**
 * @deprecated Local bundled-Lottie preloading is no longer the recommended
 * model. Use `loadAnimationSources` to fetch animation JSON from your server and
 * pass the result to `AppTextInput` as `animationSources`.
 */
export function preloadAnimatedEmojiAssets(
  _registry: AnimatedEmojiRegistry,
  _assetKeys: string[]
): Promise<void> {
  // Placeholder for native asset preloading. The native module will implement
  // the actual Lottie composition cache. This JavaScript side records the
  // requested keys so that the native layer can warm its cache when connected.
  return Promise.resolve();
}

export function clearAssetCache(): void {
  assetCache.clear();
}

/**
 * Builds an `AnimatedEmojiRegistry` from a server catalog. The returned registry
 * stores the remote `animationUrl` in `assetKey` for backward compatibility, and
 * also sets the explicit `animationUrl` field.
 */
export function buildAnimatedEmojiRegistry(
  catalog: AnimatedEmojiCatalogItem[]
): AnimatedEmojiRegistry {
  const registry: Record<string, AnimatedEmojiDefinition> = {};

  for (const item of catalog) {
    registry[item.id] = {
      id: item.id,
      shortcode: item.shortcode,
      fallback: item.fallback,
      assetKey: item.animationUrl,
      animationUrl: item.animationUrl,
    };
  }

  return registry;
}

export type LoadAnimationSourcesOptions = {
  /**
   * Fetch implementation to use. Defaults to `globalThis.fetch`. Useful for
   * tests or custom networking layers.
   */
  fetch?: typeof fetch;
};

/**
 * Fetches Lottie animation JSON for every item in a server catalog and returns a
 * map suitable for the `animationSources` prop on `AppTextInput`. Failed fetches
 * are logged in development and omitted from the result so the composer can
 * still render the static fallback emoji.
 */
export async function loadAnimationSources(
  catalog: AnimatedEmojiCatalogItem[],
  options: LoadAnimationSourcesOptions = {}
): Promise<AnimatedEmojiSources> {
  const fetchImpl = options.fetch ?? globalThis.fetch;
  const sources: AnimatedEmojiSources = {};

  await Promise.all(
    catalog.map(async (item) => {
      if (!item.animationUrl) {
        if (isDevMode()) {
          console.warn(`Animated emoji ${item.id} has no animationUrl`);
        }
        return;
      }

      try {
        const response = await fetchImpl(item.animationUrl);
        if (!response.ok) {
          throw new Error(
            `Failed to fetch ${item.animationUrl}: ${response.status}`
          );
        }
        const json = await response.json();
        sources[item.id] = json as AnimatedEmojiSources[string];
      } catch (error) {
        if (isDevMode()) {
          console.warn(
            `Failed to load animation source for ${item.id}:`,
            error
          );
        }
      }
    })
  );

  return sources;
}
