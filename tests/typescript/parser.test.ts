import {
  findActiveShortcode,
  findAnimatedEmojiDefinition,
  findCompletedShortcodeAtCaret,
  findCompletedShortcodeAtEnd,
  getShortcodeSuggestions,
  parsePastedText,
  replaceCompletedShortcode,
  resolveParserConfig,
} from '../../src/utils/parser';

const rainbow = {
  id: 'rainbow',
  shortcode: ':rainbow:',
  fallback: '🌈',
  assetKey: 'rainbow.json',
};

const rocket = {
  id: 'rocket',
  shortcode: ':rocket:',
  fallback: '🚀',
  assetKey: 'rocket.json',
};

const registry = { rainbow, rocket };

describe('resolveParserConfig', () => {
  it('uses defaults when no config is provided', () => {
    const config = resolveParserConfig();
    expect(config.trigger).toBe(':');
    expect(config.maxLength).toBe(32);
    expect(config.caseSensitive).toBe(false);
  });

  it('merges custom values', () => {
    const config = resolveParserConfig({ trigger: '#', maxLength: 10 });
    expect(config.trigger).toBe('#');
    expect(config.maxLength).toBe(10);
  });
});

describe('findActiveShortcode', () => {
  it('finds the active shortcode after the trigger', () => {
    const result = findActiveShortcode('Hello :rain', 11);
    expect(result).toEqual({ text: 'rain', range: { start: 6, end: 11 } });
  });

  it('returns null when there is no active shortcode', () => {
    const result = findActiveShortcode('Hello world', 5);
    expect(result).toBeNull();
  });

  it('returns null for a shortcode that exceeds maxLength', () => {
    const long = 'a'.repeat(40);
    const result = findActiveShortcode(`:${long}`, long.length + 1, { maxLength: 32 });
    expect(result).toBeNull();
  });
});

describe('findCompletedShortcodeAtEnd', () => {
  it('finds a completed shortcode at the end of the text', () => {
    const result = findCompletedShortcodeAtEnd('Hi :rainbow:');
    expect(result).toEqual({ shortcode: ':rainbow:', range: { start: 3, end: 12 } });
  });

  it('returns null for an incomplete shortcode', () => {
    const result = findCompletedShortcodeAtEnd('Hi :rainbow');
    expect(result).toBeNull();
  });

  it('returns null for a shortcode containing invalid characters', () => {
    const result = findCompletedShortcodeAtEnd('Hi :rain bow:');
    expect(result).toBeNull();
  });
});

describe('findCompletedShortcodeAtCaret', () => {
  it('finds a completed shortcode ending exactly at the caret', () => {
    const result = findCompletedShortcodeAtCaret('Hey :rainbow:, How are you?', 13);
    expect(result).toEqual({ shortcode: ':rainbow:', range: { start: 4, end: 13 } });
  });

  it('finds a completed shortcode ending just before a separator', () => {
    const result = findCompletedShortcodeAtCaret('Hey :rainbow: ', 14);
    expect(result).toEqual({ shortcode: ':rainbow:', range: { start: 4, end: 13 } });
  });

  it('does not replace a shortcode followed by more word characters', () => {
    const result = findCompletedShortcodeAtCaret('Hey :rainbow:hello', 18);
    expect(result).toBeNull();
  });

  it('returns null when the caret is inside an active shortcode', () => {
    const result = findCompletedShortcodeAtCaret('Hey :rainbo', 11);
    expect(result).toBeNull();
  });
});

describe('findAnimatedEmojiDefinition', () => {
  it('finds a registered emoji by shortcode', () => {
    expect(findAnimatedEmojiDefinition(registry, ':rainbow:')).toEqual(rainbow);
  });

  it('is case insensitive by default', () => {
    expect(findAnimatedEmojiDefinition(registry, ':Rainbow:')).toEqual(rainbow);
  });

  it('returns undefined for unknown shortcodes', () => {
    expect(findAnimatedEmojiDefinition(registry, ':unknown:')).toBeUndefined();
  });
});

describe('replaceCompletedShortcode', () => {
  it('replaces a completed shortcode with an entity', () => {
    const doc = { text: 'Hi :rainbow:', entities: [], revision: 0 };
    const result = replaceCompletedShortcode(doc, registry);
    expect(result.replaced).toBe(true);
    expect(result.document.text).toBe('Hi \uFFFC');
    expect(result.document.entities).toHaveLength(1);
    expect(result.document.entities[0].id).toBe('rainbow');
  });

  it('leaves unknown shortcodes unchanged', () => {
    const doc = { text: 'Hi :unknown:', entities: [], revision: 0 };
    const result = replaceCompletedShortcode(doc, registry);
    expect(result.replaced).toBe(false);
    expect(result.document.text).toBe('Hi :unknown:');
  });
});

describe('parsePastedText', () => {
  it('converts known shortcodes in pasted text', () => {
    const doc = parsePastedText('Hello :rainbow: world :rocket:', registry);
    expect(doc.text).toBe('Hello \uFFFC world \uFFFC');
    expect(doc.entities).toHaveLength(2);
    expect(doc.entities[0].id).toBe('rainbow');
    expect(doc.entities[1].id).toBe('rocket');
  });

  it('leaves unknown shortcodes as plain text', () => {
    const doc = parsePastedText('Hello :unknown:', registry);
    expect(doc.text).toBe('Hello :unknown:');
    expect(doc.entities).toHaveLength(0);
  });
});

describe('getShortcodeSuggestions', () => {
  it('returns matching definitions for a query', () => {
    const suggestions = getShortcodeSuggestions('rai', registry);
    expect(suggestions).toEqual([rainbow]);
  });

  it('returns an empty array when nothing matches', () => {
    const suggestions = getShortcodeSuggestions('xyz', registry);
    expect(suggestions).toEqual([]);
  });
});
