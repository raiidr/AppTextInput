import {
  createAnimatedEmojiEntity,
  createDocument,
  documentToMessageApiPayload,
  documentToShortcodeFallback,
  documentToUnicodeFallback,
  documentToValue,
  findEntityAtOffset,
  insertTextIntoDocument,
  normalizeSelection,
  removeEntitiesInRange,
  replaceRangeInDocument,
  shiftEntitiesAfterRange,
  shortcodeFallbackToDocument,
  validateDocument,
} from '../../src/utils/document';

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

describe('createDocument', () => {
  it('creates a valid empty document', () => {
    const doc = createDocument('');
    expect(doc.text).toBe('');
    expect(doc.entities).toEqual([]);
    expect(doc.revision).toBe(0);
  });

  it('throws for overlapping entities when validation is strict', () => {
    expect(() =>
      validateDocument(
        {
          text: '\uFFFC\uFFFC',
          entities: [
            createAnimatedEmojiEntity(rainbow, 0),
            { ...createAnimatedEmojiEntity(rocket, 0), id: 'rocket' },
          ],
          revision: 0,
        },
        { throwOnError: true }
      )
    ).toThrow();
  });
});

describe('validateDocument', () => {
  it('accepts a valid document', () => {
    const doc = createDocument('a\uFFFCb', [createAnimatedEmojiEntity(rainbow, 1)]);
    expect(validateDocument(doc)).toEqual({ valid: true, errors: [] });
  });

  it('rejects an entity not on an object replacement character', () => {
    const doc = createDocument('abc', [createAnimatedEmojiEntity(rainbow, 1)]);
    const result = validateDocument(doc);
    expect(result.valid).toBe(false);
    expect(result.errors[0]).toContain('object replacement character');
  });

  it('rejects an entity with an offset outside the text', () => {
    const doc = createDocument('a', [createAnimatedEmojiEntity(rainbow, 5)]);
    const result = validateDocument(doc);
    expect(result.valid).toBe(false);
  });
});

describe('insertTextIntoDocument', () => {
  it('shifts entities after the insertion point', () => {
    const doc = createDocument('a\uFFFCb', [createAnimatedEmojiEntity(rainbow, 1)]);
    const next = insertTextIntoDocument(doc, 1, 'xx');
    expect(next.text).toBe('axx\uFFFCb');
    expect(next.entities[0].offset).toBe(3);
  });
});

describe('removeEntitiesInRange', () => {
  it('removes entities that intersect the range', () => {
    const entities = [
      createAnimatedEmojiEntity(rainbow, 0),
      createAnimatedEmojiEntity(rocket, 5),
    ];
    const remaining = removeEntitiesInRange(entities, { start: 0, end: 2 });
    expect(remaining).toHaveLength(1);
    expect(remaining[0].id).toBe('rocket');
  });
});

describe('replaceRangeInDocument', () => {
  it('replaces text and inserts entities', () => {
    const doc = createDocument('Hello world', [], 1);
    const next = replaceRangeInDocument(doc, { start: 6, end: 11 }, '\uFFFC', [
      createAnimatedEmojiEntity(rainbow, 6),
    ]);
    expect(next.text).toBe('Hello \uFFFC');
    expect(next.entities[0].offset).toBe(6);
  });
});

describe('shiftEntitiesAfterRange', () => {
  it('shifts entities after the range by delta', () => {
    const entities = [createAnimatedEmojiEntity(rainbow, 5)];
    const shifted = shiftEntitiesAfterRange(entities, { start: 2, end: 4 }, 3);
    expect(shifted[0].offset).toBe(8);
  });
});

describe('documentToShortcodeFallback', () => {
  it('renders shortcodes for known entities', () => {
    const doc = createDocument('\uFFFC', [createAnimatedEmojiEntity(rainbow, 0)]);
    expect(documentToShortcodeFallback(doc, { rainbow })).toBe(':rainbow:');
  });
});

describe('documentToUnicodeFallback', () => {
  it('renders Unicode fallback for entities', () => {
    const doc = createDocument('a\uFFFCb', [createAnimatedEmojiEntity(rainbow, 1)]);
    expect(documentToUnicodeFallback(doc)).toBe('a🌈b');
  });
});

describe('documentToMessageApiPayload', () => {
  it('serializes animated emoji entities', () => {
    const doc = createDocument('a\uFFFCb', [createAnimatedEmojiEntity(rainbow, 1)]);
    const payload = documentToMessageApiPayload(doc);
    expect(payload.text).toBe('a\uFFFCb');
    expect(payload.animatedEmoji).toEqual([
      { id: 'rainbow', shortcode: ':rainbow:', assetKey: 'rainbow.json', offset: 1 },
    ]);
  });
});

describe('findEntityAtOffset', () => {
  it('finds an entity at an offset', () => {
    const entity = createAnimatedEmojiEntity(rainbow, 2);
    const doc = createDocument('aa\uFFFCbb', [entity]);
    expect(findEntityAtOffset(doc, 2)).toEqual(entity);
    expect(findEntityAtOffset(doc, 3)).toBeUndefined();
  });
});

describe('normalizeSelection', () => {
  it('pushes the selection out of an entity', () => {
    const doc = createDocument('a\uFFFCb', [createAnimatedEmojiEntity(rainbow, 1)]);
    expect(normalizeSelection(doc, { start: 1, end: 1 })).toEqual({ start: 2, end: 2 });
  });
});

describe('shortcodeFallbackToDocument', () => {
  it('converts known shortcodes to entities', () => {
    const doc = shortcodeFallbackToDocument('Hi :rainbow:!', { rainbow });
    expect(doc.text).toBe('Hi \uFFFC!');
    expect(doc.entities).toHaveLength(1);
    expect(doc.entities[0].id).toBe('rainbow');
  });

  it('leaves unknown shortcodes as plain text', () => {
    const doc = shortcodeFallbackToDocument('Hi :unknown:!', { rainbow });
    expect(doc.text).toBe('Hi :unknown:!');
    expect(doc.entities).toHaveLength(0);
  });
});

describe('documentToValue', () => {
  it('includes the revision in the value', () => {
    const doc = createDocument('hello', [], 7);
    expect(documentToValue(doc)).toEqual({ text: 'hello', entities: [], revision: 7 });
  });
});
