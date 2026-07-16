import {
  OBJECT_REPLACEMENT_CHARACTER,
  type AnimatedEmojiDefinition,
  type AnimatedEmojiEntity,
  type AnimatedEmojiRegistry,
  type AppTextEntity,
  type AppTextInputValue,
  type TextRange,
} from '../types';

export type AppTextDocument = {
  text: string;
  entities: AppTextEntity[];
  revision: number;
};

const isValidOffset = (text: string, offset: number): boolean => {
  return offset >= 0 && offset <= text.length;
};

const isWithinEntity = (entity: AppTextEntity, offset: number): boolean => {
  return offset >= entity.offset && offset < entity.offset + entity.length;
};

const entitiesOverlap = (a: AppTextEntity, b: AppTextEntity): boolean => {
  const aStart = a.offset;
  const aEnd = a.offset + a.length;
  const bStart = b.offset;
  const bEnd = b.offset + b.length;
  return aStart < bEnd && bStart < aEnd;
};

const isDevMode = (): boolean =>
  typeof __DEV__ !== 'undefined' && __DEV__ === true;

export function createDocument(
  text: string,
  entities: AppTextEntity[] = [],
  revision = 0
): AppTextDocument {
  const doc = { text, entities: normalizeEntities(entities), revision };
  validateDocument(doc, { throwOnError: isDevMode() });
  return doc;
}

export function normalizeEntities(entities: AppTextEntity[]): AppTextEntity[] {
  return [...entities].sort((a, b) => a.offset - b.offset);
}

export function validateDocument(
  doc: AppTextDocument,
  options: { throwOnError?: boolean } = {}
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (typeof doc.text !== 'string') {
    errors.push('Document text must be a string.');
  }

  const textLength = doc.text?.length ?? 0;

  for (const entity of doc.entities) {
    if (entity.length !== 1) {
      errors.push(
        `Entity ${entity.id} has length ${entity.length}; expected 1.`
      );
    }

    if (!isValidOffset(doc.text, entity.offset)) {
      errors.push(
        `Entity ${entity.id} offset ${entity.offset} is outside text of length ${textLength}.`
      );
    }

    if (!isValidOffset(doc.text, entity.offset + entity.length)) {
      errors.push(
        `Entity ${entity.id} end offset ${entity.offset + entity.length} is outside text of length ${textLength}.`
      );
    }

    const charAt = doc.text.charAt(entity.offset);
    if (charAt !== OBJECT_REPLACEMENT_CHARACTER) {
      errors.push(
        `Entity ${entity.id} at offset ${entity.offset} does not sit on an object replacement character (found "${charAt}").`
      );
    }
  }

  for (let i = 0; i < doc.entities.length - 1; i++) {
    for (let j = i + 1; j < doc.entities.length; j++) {
      if (entitiesOverlap(doc.entities[i], doc.entities[j])) {
        errors.push(
          `Entities ${doc.entities[i].id} and ${doc.entities[j].id} overlap.`
        );
      }
    }
  }

  const valid = errors.length === 0;

  if (!valid && options.throwOnError) {
    throw new Error(`Invalid document: ${errors.join('; ')}`);
  }

  return { valid, errors };
}

export function shiftEntitiesAfterRange(
  entities: AppTextEntity[],
  range: TextRange,
  delta: number
): AppTextEntity[] {
  return entities.map((entity) => {
    if (entity.offset >= range.end) {
      return { ...entity, offset: entity.offset + delta };
    }

    if (entity.offset + entity.length <= range.start) {
      return entity;
    }

    return entity;
  });
}

export function removeEntitiesInRange(
  entities: AppTextEntity[],
  range: TextRange
): AppTextEntity[] {
  return entities.filter(
    (entity) =>
      entity.offset >= range.end || entity.offset + entity.length <= range.start
  );
}

export function insertTextIntoDocument(
  doc: AppTextDocument,
  position: number,
  text: string,
  entities: AppTextEntity[] = []
): AppTextDocument {
  const newText = doc.text.slice(0, position) + text + doc.text.slice(position);
  const shiftedEntities = shiftEntitiesAfterRange(
    doc.entities,
    { start: position, end: position },
    text.length
  );
  const insertedEntities = entities.map((entity) => ({
    ...entity,
    offset: entity.offset + position,
  }));
  const newEntities = normalizeEntities([...shiftedEntities, ...insertedEntities]);
  return { text: newText, entities: newEntities, revision: doc.revision + 1 };
}

export function deleteRangeFromDocument(
  doc: AppTextDocument,
  range: TextRange
): AppTextDocument {
  const safeStart = Math.max(0, Math.min(range.start, doc.text.length));
  const safeEnd = Math.max(safeStart, Math.min(range.end, doc.text.length));
  const removedLength = safeEnd - safeStart;

  const newText = doc.text.slice(0, safeStart) + doc.text.slice(safeEnd);
  const survivingEntities = removeEntitiesInRange(doc.entities, {
    start: safeStart,
    end: safeEnd,
  });
  const shiftedEntities = shiftEntitiesAfterRange(
    survivingEntities,
    { start: safeStart, end: safeEnd },
    -removedLength
  );

  return {
    text: newText,
    entities: normalizeEntities(shiftedEntities),
    revision: doc.revision + 1,
  };
}

export function replaceRangeInDocument(
  doc: AppTextDocument,
  range: TextRange,
  text: string,
  entities: AppTextEntity[] = []
): AppTextDocument {
  const safeStart = Math.max(0, Math.min(range.start, doc.text.length));
  const safeEnd = Math.max(safeStart, Math.min(range.end, doc.text.length));
  const withoutDeleted = deleteRangeFromDocument(doc, { start: safeStart, end: safeEnd });
  const relativeEntities = entities.map((entity) => ({
    ...entity,
    offset: entity.offset - safeStart,
  }));
  return insertTextIntoDocument(withoutDeleted, safeStart, text, relativeEntities);
}

export function createAnimatedEmojiEntity(
  definition: AnimatedEmojiDefinition,
  offset: number
): AnimatedEmojiEntity {
  return {
    type: 'animated-emoji',
    id: definition.id,
    shortcode: definition.shortcode,
    fallback: definition.fallback,
    assetKey: definition.assetKey,
    offset,
    length: 1,
  };
}

export function documentToNativeText(doc: AppTextDocument): string {
  return doc.text;
}

export function nativeTextToDocument(
  text: string,
  entities: AppTextEntity[] = [],
  revision = 0
): AppTextDocument {
  return createDocument(text, entities, revision);
}

export function documentToValue(doc: AppTextDocument): AppTextInputValue {
  return {
    text: doc.text,
    entities: doc.entities,
    revision: doc.revision,
  };
}

export function valueToDocument(value: AppTextInputValue): AppTextDocument {
  return createDocument(value.text, value.entities, value.revision ?? 0);
}

export function documentToShortcodeFallback(
  doc: AppTextDocument,
  registry?: AnimatedEmojiRegistry
): string {
  let result = '';
  let lastIndex = 0;

  for (const entity of doc.entities) {
    result += doc.text.slice(lastIndex, entity.offset);
    const definition = registry?.[entity.id];
    result += definition?.shortcode ?? entity.shortcode ?? `:${entity.id}:`;
    lastIndex = entity.offset + entity.length;
  }

  result += doc.text.slice(lastIndex);
  return result;
}

export function documentToUnicodeFallback(
  doc: AppTextDocument,
  registry?: AnimatedEmojiRegistry
): string {
  let result = '';
  let lastIndex = 0;

  for (const entity of doc.entities) {
    result += doc.text.slice(lastIndex, entity.offset);
    const definition = registry?.[entity.id];
    result += definition?.fallback ?? entity.fallback ?? OBJECT_REPLACEMENT_CHARACTER;
    lastIndex = entity.offset + entity.length;
  }

  result += doc.text.slice(lastIndex);
  return result;
}

export type MessageApiPayload = {
  text: string;
  animatedEmoji: Array<{
    id: string;
    shortcode: string;
    assetKey: string;
    offset: number;
  }>;
};

export function documentToMessageApiPayload(
  doc: AppTextDocument
): MessageApiPayload {
  return {
    text: doc.text,
    animatedEmoji: doc.entities
      .filter((entity): entity is AnimatedEmojiEntity => entity.type === 'animated-emoji')
      .map((entity) => ({
        id: entity.id,
        shortcode: entity.shortcode,
        assetKey: entity.assetKey,
        offset: entity.offset,
      })),
  };
}

export function shortcodeFallbackToDocument(
  text: string,
  registry: AnimatedEmojiRegistry,
  revision = 0
): AppTextDocument {
  const entities: AppTextEntity[] = [];
  let resultText = '';

  const shortcodePattern = /:([a-zA-Z0-9_-]+):/g;
  let match: RegExpExecArray | null;
  let lastIndex = 0;

  while ((match = shortcodePattern.exec(text)) !== null) {
    const shortcode = `:${match[1]}:`;
    const definition = Object.values(registry).find(
      (def) => def.shortcode === shortcode
    );

    if (definition) {
      resultText += text.slice(lastIndex, match.index);
      const offset = resultText.length;
      resultText += OBJECT_REPLACEMENT_CHARACTER;
      entities.push(createAnimatedEmojiEntity(definition, offset));
      lastIndex = match.index + shortcode.length;
    }
  }

  resultText += text.slice(lastIndex);
  return createDocument(resultText, entities, revision);
}

export function cloneDocument(doc: AppTextDocument): AppTextDocument {
  return {
    text: doc.text,
    entities: doc.entities.map((entity) => ({ ...entity })),
    revision: doc.revision,
  };
}

export function setRevision(doc: AppTextDocument, revision: number): AppTextDocument {
  return { ...doc, revision };
}

export function findEntityAtOffset(
  doc: AppTextDocument,
  offset: number
): AppTextEntity | undefined {
  return doc.entities.find((entity) => isWithinEntity(entity, offset));
}

export function normalizeSelection(
  doc: AppTextDocument,
  selection: TextRange
): TextRange {
  let start = Math.max(0, Math.min(selection.start, doc.text.length));
  let end = Math.max(start, Math.min(selection.end, doc.text.length));

  const startEntity = findEntityAtOffset(doc, start);
  if (startEntity) {
    start = startEntity.offset + startEntity.length;
  }

  const endEntity = findEntityAtOffset(doc, end);
  if (endEntity) {
    end = endEntity.offset;
  }

  return { start: Math.max(start, 0), end: Math.max(start, end) };
}

export function getEntityCount(doc: AppTextDocument): number {
  return doc.entities.length;
}
