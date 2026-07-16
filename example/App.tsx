import React, { useEffect, useRef, useState } from 'react';
import {
  Button,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  AppTextInput,
  buildAnimatedEmojiRegistry,
  loadAnimationSources,
  type AnimatedEmojiCatalogItem,
  type AnimatedEmojiSources,
  type AppTextInputRef,
  type AppTextInputValue,
  type ShortcodeQuery,
} from '@app/app-text-input';

// In a real app this catalog comes from your server (e.g. animatedEmojiCatalog.php).
// Each item points to a remote Lottie JSON URL. The example uses a tiny mock
// fetch so it works offline while still demonstrating the server-driven flow.
const CATALOG: AnimatedEmojiCatalogItem[] = [
  {
    id: 'rainbow',
    shortcode: ':rainbow:',
    fallback: '🌈',
    animationUrl: 'https://example-cdn.app/animated-emoji/rainbow.json',
  },
  {
    id: 'rocket',
    shortcode: ':rocket:',
    fallback: '🚀',
    animationUrl: 'https://example-cdn.app/animated-emoji/rocket.json',
  },
  {
    id: 'fire',
    shortcode: ':fire:',
    fallback: '🔥',
    animationUrl: 'https://example-cdn.app/animated-emoji/fire.json',
  },
  {
    id: 'heart',
    shortcode: ':heart:',
    fallback: '❤️',
    animationUrl: 'https://example-cdn.app/animated-emoji/heart.json',
  },
  {
    id: 'wave',
    shortcode: ':wave:',
    fallback: '👋',
    animationUrl: 'https://example-cdn.app/animated-emoji/wave.json',
  },
];

// Minimal valid Lottie JSON used as a stand-in for real server payloads.
function mockLottie(name: string) {
  return {
    v: '5.5.7',
    fr: 60,
    ip: 0,
    op: 60,
    w: 64,
    h: 64,
    nm: name,
    ddd: 0,
    layers: [],
  };
}

async function mockFetch(input: string | URL | Request): Promise<Response> {
  const url = typeof input === 'string' ? input : input.toString();
  const name = url.split('/').pop()?.replace('.json', '') ?? 'emoji';
  return new Response(JSON.stringify(mockLottie(name)), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default function Example() {
  const inputRef = useRef<AppTextInputRef>(null);
  const [value, setValue] = useState<AppTextInputValue>({ text: '', entities: [] });
  const [query, setQuery] = useState<ShortcodeQuery>(null);
  const [animationSources, setAnimationSources] = useState<AnimatedEmojiSources>({});

  const registry = buildAnimatedEmojiRegistry(CATALOG);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const sources = await loadAnimationSources(CATALOG, { fetch: mockFetch });
      if (!cancelled) {
        setAnimationSources(sources);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.label}>Composer</Text>
        <AppTextInput
          ref={inputRef}
          value={value}
          onChange={setValue}
          onShortcodeQueryChange={setQuery}
          animatedEmojiRegistry={registry}
          animationSources={animationSources}
          multiline
          placeholder="Type a message..."
          style={styles.input}
        />

        {query && (
          <View style={styles.suggestions}>
            <Text style={styles.suggestionsTitle}>
              Active shortcode: {query.text}
            </Text>
          </View>
        )}

        <View style={styles.buttons}>
          <Button title="Focus" onPress={() => inputRef.current?.focus()} />
          <Button title="Blur" onPress={() => inputRef.current?.blur()} />
          <Button title="Clear" onPress={() => inputRef.current?.clear()} />
          <Button
            title="Insert rainbow"
            onPress={() => inputRef.current?.insertAnimatedEmoji(registry.rainbow)}
          />
        </View>

        <Text style={styles.label}>Structured value</Text>
        <Text style={styles.mono}>{JSON.stringify(value, null, 2)}</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 16,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    marginTop: 16,
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    padding: 12,
    minHeight: 80,
    fontSize: 16,
  },
  suggestions: {
    marginTop: 8,
    padding: 8,
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
  },
  suggestionsTitle: {
    fontSize: 14,
  },
  buttons: {
    marginTop: 16,
    gap: 8,
  },
  mono: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 12,
    backgroundColor: '#f5f5f5',
    padding: 8,
    borderRadius: 8,
  },
});
