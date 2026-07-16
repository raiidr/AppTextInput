import {
  OBJECT_REPLACEMENT_CHARACTER,
  type AnimatedEmojiDefinition,
  type AnimatedEmojiRegistry,
  type ShortcodeParserConfig,
  type ShortcodeQuery,
  type TextRange,
} from '../types';
import type { AppTextDocument } from '../utils/document';
import {
  createAnimatedEmojiEntity,
  createDocument,
  replaceRangeInDocument,
} from './document';

const DEFAULT_CONFIG: Required<ShortcodeParserConfig> = {
  trigger: ':',
  allowedCharacters: /^[a-zA-Z0-9_-]$/,
  maxLength: 32,
  caseSensitive: false,
  replaceOnSpace: true,
};

export function resolveParserConfig(
  config: ShortcodeParserConfig = {}
): Required<ShortcodeParserConfig> {
  return {
    trigger: config.trigger ?? DEFAULT_CONFIG.trigger,
    allowedCharacters: config.allowedCharacters ?? DEFAULT_CONFIG.allowedCharacters,
    maxLength: config.maxLength ?? DEFAULT_CONFIG.maxLength,
    caseSensitive: config.caseSensitive ?? DEFAULT_CONFIG.caseSensitive,
    replaceOnSpace: config.replaceOnSpace ?? DEFAULT_CONFIG.replaceOnSpace,
  };
}

export function findActiveShortcode(
  text: string,
  caret: number,
  config: ShortcodeParserConfig = {}
): ShortcodeQuery {
  const resolved = resolveParserConfig(config);
  const trigger = resolved.trigger;

  if (caret < 0 || caret > text.length) {
    return null;
  }

  let start = caret - 1;

  while (start >= 0) {
    const char = text.charAt(start);
    if (char === trigger) {
      break;
    }
    if (!resolved.allowedCharacters.test(char)) {
      return null;
    }
    start--;
  }

  if (start < 0 || text.charAt(start) !== trigger) {
    return null;
  }

  const queryText = text.slice(start + 1, caret);

  if (queryText.length === 0 || queryText.length > resolved.maxLength) {
    return null;
  }

  return {
    text: queryText,
    range: { start, end: caret },
  };
}

export function findCompletedShortcodeAtEnd(
  text: string,
  config: ShortcodeParserConfig = {}
): { shortcode: string; range: TextRange } | null {
  const resolved = resolveParserConfig(config);
  const trigger = escapeRegExp(resolved.trigger);
  const pattern = new RegExp(
    `${trigger}([a-zA-Z0-9_-]{1,${resolved.maxLength}})${trigger}$`
  );

  const match = text.match(pattern);
  if (!match) {
    return null;
  }

  const shortcode = `${resolved.trigger}${match[1]}${resolved.trigger}`;
  const start = text.length - shortcode.length;

  return {
    shortcode,
    range: { start, end: text.length },
  };
}

/**
 * Finds a completed shortcode that ends exactly at the caret, or a completed
 * shortcode that ends just before the caret when the caret sits on a separator
 * character (e.g. a space or comma). This matches the Telegram-style behaviour
 * where typing `:rainbow:` followed by a space immediately converts the emoji
 * even if the user has already typed the separator before the JS change handler
 * runs.
 */
export function findCompletedShortcodeAtCaret(
  text: string,
  caret: number,
  config: ShortcodeParserConfig = {}
): { shortcode: string; range: TextRange } | null {
  const resolved = resolveParserConfig(config);
  if (caret < 0 || caret > text.length) {
    return null;
  }

  // A shortcode ending exactly at the caret is the most common case.
  const exact = findCompletedShortcodeAtEnd(text.slice(0, caret), config);
  if (exact) {
    return exact;
  }

  // If the caret is right after a separator, check whether the text before
  // that separator ends with a completed shortcode. We only consider a single
  // separator so we do not accidentally convert `:rainbow:` while the user is
  // still typing inside the shortcode (e.g. `:rainbow:` followed by `h`).
  if (caret > 0) {
    const char = text.charAt(caret - 1);
    if (!resolved.allowedCharacters.test(char) && char !== resolved.trigger) {
      const before = text.slice(0, caret - 1);
      const near = findCompletedShortcodeAtEnd(before, config);
      if (near && near.range.end === before.length) {
        return near;
      }
    }
  }

  return null;
}

function normalizeShortcode(shortcode: string, config: Required<ShortcodeParserConfig>): string {
  return config.caseSensitive ? shortcode : shortcode.toLowerCase();
}

export function findAnimatedEmojiDefinition(
  registry: AnimatedEmojiRegistry,
  shortcode: string,
  config: ShortcodeParserConfig = {}
): AnimatedEmojiDefinition | undefined {
  const resolved = resolveParserConfig(config);
  const normalized = normalizeShortcode(shortcode, resolved);

  return Object.values(registry).find((def) => {
    const defShortcode = normalizeShortcode(def.shortcode, resolved);
    return defShortcode === normalized;
  });
}

export function replaceCompletedShortcode(
  doc: AppTextDocument,
  registry: AnimatedEmojiRegistry,
  config: ShortcodeParserConfig = {}
): { document: AppTextDocument; replaced: boolean; definition?: AnimatedEmojiDefinition } {
  const resolved = resolveParserConfig(config);
  const completed = findCompletedShortcodeAtEnd(doc.text, config);

  if (!completed) {
    return { document: doc, replaced: false };
  }

  const definition = findAnimatedEmojiDefinition(registry, completed.shortcode, config);

  if (!definition) {
    return { document: doc, replaced: false };
  }

  const entity = createAnimatedEmojiEntity(definition, completed.range.start);
  const newDocument = replaceRangeInDocument(
    doc,
    completed.range,
    OBJECT_REPLACEMENT_CHARACTER,
    [entity]
  );

  return { document: newDocument, replaced: true, definition };
}

export function parsePastedText(
  text: string,
  registry: AnimatedEmojiRegistry,
  config: ShortcodeParserConfig = {}
): AppTextDocument {
  const resolved = resolveParserConfig(config);
  const entities: ReturnType<typeof createAnimatedEmojiEntity>[] = [];
  let resultText = '';
  const pattern = new RegExp(
    `${escapeRegExp(resolved.trigger)}([a-zA-Z0-9_-]+)${escapeRegExp(resolved.trigger)}`,
    'g'
  );

  let match: RegExpExecArray | null;
  let lastIndex = 0;

  while ((match = pattern.exec(text)) !== null) {
    const shortcode = `${resolved.trigger}${match[1]}${resolved.trigger}`;
    const normalized = normalizeShortcode(shortcode, resolved);
    const definition = Object.values(registry).find(
      (def) => normalizeShortcode(def.shortcode, resolved) === normalized
    );

    if (definition) {
      resultText += text.slice(lastIndex, match.index);
      const offset = resultText.length;
      resultText += OBJECT_REPLACEMENT_CHARACTER;
      entities.push(createAnimatedEmojiEntity(definition, offset));
    } else {
      resultText += text.slice(lastIndex, match.index + shortcode.length);
    }

    lastIndex = match.index + shortcode.length;
  }

  resultText += text.slice(lastIndex);
  return createDocument(resultText, entities, 0);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function getShortcodeSuggestions(
  query: string,
  registry: AnimatedEmojiRegistry,
  config: ShortcodeParserConfig = {}
): AnimatedEmojiDefinition[] {
  const resolved = resolveParserConfig(config);
  const normalizedQuery = normalizeShortcode(query, resolved);

  return Object.values(registry).filter((def) => {
    const normalized = normalizeShortcode(def.shortcode, resolved);
    return normalized.includes(normalizedQuery);
  });
}

export function shouldCancelShortcode(
  text: string,
  caret: number,
  config: ShortcodeParserConfig = {}
): boolean {
  const active = findActiveShortcode(text, caret, config);
  return active === null;
}
