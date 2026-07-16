import {
  buildAnimatedEmojiRegistry,
  loadAnimationSources,
} from '../../src/utils/assets';
import type { AnimatedEmojiCatalogItem } from '../../src/types';

const catalog: AnimatedEmojiCatalogItem[] = [
  {
    id: 'rainbow',
    shortcode: ':rainbow:',
    fallback: '🌈',
    animationUrl: 'https://example.app/emoji/rainbow.json',
  },
  {
    id: 'rocket',
    shortcode: ':rocket:',
    fallback: '🚀',
    animationUrl: 'https://example.app/emoji/rocket.json',
  },
];

describe('buildAnimatedEmojiRegistry', () => {
  it('builds a registry from a server catalog', () => {
    const registry = buildAnimatedEmojiRegistry(catalog);

    expect(Object.keys(registry)).toEqual(['rainbow', 'rocket']);
    expect(registry.rainbow).toEqual({
      id: 'rainbow',
      shortcode: ':rainbow:',
      fallback: '🌈',
      assetKey: 'https://example.app/emoji/rainbow.json',
      animationUrl: 'https://example.app/emoji/rainbow.json',
    });
  });

  it('returns an empty registry for an empty catalog', () => {
    expect(buildAnimatedEmojiRegistry([])).toEqual({});
  });
});

describe('loadAnimationSources', () => {
  it('fetches animation JSON for each catalog item', async () => {
    const fetchImpl = jest.fn().mockImplementation(async (url: string) => ({
      ok: true,
      json: async () => ({ v: '5.5.7', url }),
    }));

    const sources = await loadAnimationSources(catalog, { fetch: fetchImpl as unknown as typeof fetch });

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(sources).toEqual({
      rainbow: { v: '5.5.7', url: 'https://example.app/emoji/rainbow.json' },
      rocket: { v: '5.5.7', url: 'https://example.app/emoji/rocket.json' },
    });
  });

  it('returns an empty object for an empty catalog', async () => {
    const sources = await loadAnimationSources([], { fetch: jest.fn() as unknown as typeof fetch });
    expect(sources).toEqual({});
  });

  it('omits items with missing animationUrl', async () => {
    const fetchImpl = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ v: '5.5.7' }),
    });

    const sources = await loadAnimationSources(
      [{ id: 'ghost', shortcode: ':ghost:', fallback: '👻', animationUrl: '' }],
      { fetch: fetchImpl as unknown as typeof fetch }
    );

    expect(sources).toEqual({});
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('omits failed fetches without rejecting', async () => {
    const fetchImpl = jest.fn().mockResolvedValue({
      ok: false,
      status: 500,
    });

    const sources = await loadAnimationSources([catalog[0]], { fetch: fetchImpl as unknown as typeof fetch });

    expect(sources).toEqual({});
  });
});
