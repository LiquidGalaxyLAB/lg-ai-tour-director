# Universal LLM Integration for Flutter
## GSoC 2026 | Kabir Singh Khanuja | Liquid Galaxy

> **One question this answers:** *"I want to call any LLM from my Flutter app.
> How do I do it in 5 minutes?"*
>
> **The answer:** copy 3 files, show a config screen to the user once, then call
> `LLMClient.generate(systemPrompt, userPrompt)` and use the text you get back.
> You write your own prompts. You parse the reply however you like. You build
> your own feature. We just give you the HTTP caller and the config UI.

---

## 1. Overview

This is a tiny, reusable way to talk to **any OpenAI-compatible LLM** from a
Flutter app. OpenRouter, Groq, Together.ai, OpenAI, and local runners like
Ollama and LM Studio all accept the **same** request format. So instead of a
different SDK per provider, you configure just three values — a **Base URL**, an
**API Key**, and a **Model ID** — and one function talks to all of them. There
is no provider-specific code anywhere.

---

## 2. Why It Matters for LG Projects

- **Provider-agnostic.** DeepSeek, GPT, Llama, Mistral, local models — all work
  through the same call, with **zero code changes**. The provider is data the
  user types, not code you ship.
- **Free-tier friendly.** A student with no budget can point it at a local
  Ollama model and pay nothing. Someone else can use a paid cloud model. Same
  code.
- **One code path.** No `if (provider == 'openai')` branches. One function,
  every model. Easy to read, easy to trust, easy to reuse.

---

## 3. Architecture (the whole thing)

```
  Your code
     │  LLMClient.generate(systemPrompt, userPrompt)
     ▼
  POST  {baseUrl}/chat/completions
        headers: Authorization: Bearer <apiKey>
        body:    { model, messages: [system, user], temperature }
     │
     ▼
  Provider runs the model
     │
     ▼
  Returns a plain text String   ──►   you do whatever you want with it
```

That is the entire pattern. No pipeline, no framework, no magic.

---

## 4. The 3 Files to Copy

Keep the same folders under your `lib/`.

| File | Class | What it does |
|---|---|---|
| `lib/services/llm/llm_client.dart` | `LLMClient` | The universal caller. Builds the HTTP request, sends it to `{baseUrl}/chat/completions`, and returns the model's text. **This is the only thing you must call.** |
| `lib/services/llm/llm_exception.dart` | `LlmException` | Turns raw HTTP failures (bad key, no credit, wrong model, timeout) into short, friendly messages you can show the user. |
| `lib/screens/settings/ai_model_screen.dart` | `AiModelScreen` | A ready-made settings screen where the user pastes their Base URL, API Key, and Model ID, taps **Test Connection**, and saves. Reuse it as-is. |

> **Dependencies:** these files need `dio` (HTTP) and `shared_preferences`
> (to remember the user's config). Both are common Flutter packages.

---

## 5. `LLMClient.generate()` — the one function you call

```dart
Future<String> generate({
  required String systemPrompt,
  required String userPrompt,
}) async {
  final url = '$baseUrl/chat/completions';
  try {
    final response = await _dio.post(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
      },
    );
    final content =
        response.data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw LlmException('The model returned an empty response.');
    }
    return content;
  } on DioException catch (e) {
    throw LlmException.fromDio(e);
  }
}
```

**The constructor** takes the three config values:

```dart
final client = LLMClient(
  baseUrl: 'https://openrouter.ai/api/v1',
  apiKey: 'sk-or-...',
  model: 'deepseek/deepseek-chat',
);
```

- **Parameters of `generate`:**
  - `systemPrompt` — the instructions / role ("who the AI is, what rules it
    follows").
  - `userPrompt` — the actual request from your feature.
- **Returns:** the model's reply as a plain `String`.
- **Throws:** `LlmException` with a friendly message if anything goes wrong.

**Generic example** (nothing app-specific — just ask a question):

```dart
final answer = await client.generate(
  systemPrompt: 'You are a helpful assistant. Answer in one short sentence.',
  userPrompt: 'What is the capital of France?',
);
print(answer); // "The capital of France is Paris."
```

Want structured output? Ask for it in the system prompt and parse the String
yourself — that part is **your** feature, not this library's job:

```dart
final reply = await client.generate(
  systemPrompt: 'Reply ONLY with JSON: {"answer": "..."}',
  userPrompt: 'Capital of Japan?',
);
// reply is a String. Parse it however your feature needs.
```

**Why designed this way:** every OpenAI-compatible provider accepts this exact
body at this exact path. By making `baseUrl`, `apiKey`, and `model` constructor
arguments (not hardcoded values), one function reaches every provider. The
30-second timeouts stop the UI from hanging on a slow or dead endpoint.

---

## 6. `LLMClient.testConnection()` — confirm it works

```dart
Future<void> testConnection() =>
    generate(systemPrompt: 'Reply with exactly: OK', userPrompt: 'test');
```

- **Parameters:** none.
- **Returns:** nothing on success; **throws `LlmException`** on failure.
- **Use it like this:**

```dart
try {
  await client.testConnection();
  print('Connected!');
} on LlmException catch (e) {
  print('Failed: ${e.message}');
}
```

It sends one tiny request, so a success proves the URL is reachable, the key is
valid, and the model exists — all at once. The **Test Connection** button in the
config screen calls exactly this.

---

## 7. Supported Providers (example configs)

| Provider | Base URL | Model Example | API Key |
|---|---|---|---|
| OpenRouter | `https://openrouter.ai/api/v1` | `deepseek/deepseek-chat` | `sk-or-...` |
| Groq | `https://api.groq.com/openai/v1` | `llama-3.1-8b-instant` | `gsk_...` |
| Together.ai | `https://api.together.xyz/v1` | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | `...` |
| Ollama (local) | `http://localhost:11434/v1` | `llama3` | *(empty)* |
| LM Studio (local) | `http://localhost:1234/v1` | `local-model` | *(empty)* |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` | `sk-...` |

> **Free options:** OpenRouter has `:free` models (e.g.
> `meta-llama/llama-3.1-8b-instruct:free`), and **Ollama / LM Studio are fully
> free** because the model runs on your own machine.

---

## 8. How to Integrate (4 steps)

**Step 1 — Copy the 3 files** (Section 4) into your `lib/`, then add the
dependencies:

```yaml
dependencies:
  dio: ^5.9.2
  shared_preferences: ^2.5.5
```

Run `flutter pub get`.

**Step 2 — Show the config screen once** so the user enters their credentials:

```dart
Navigator.push(context,
    MaterialPageRoute(builder: (_) => const AiModelScreen()));
```

The screen saves the Base URL, API Key, and Model ID for you (using
`shared_preferences`). You only need to show it once; the values persist.

**Step 3 — Call `generate()` with your own prompts:**

```dart
final client = LLMClient(baseUrl: baseUrl, apiKey: apiKey, model: model);

final result = await client.generate(
  systemPrompt: 'You are a translator. Translate the input to French.',
  userPrompt: 'Good morning',
);
```

> Load the saved values with `shared_preferences` (three `getString` reads), or
> just pass your own values directly to the constructor — either works. If you
> prefer, keep the tiny helper that the config screen uses to store/read them.

**Step 4 — Use the String.** Show it, parse it, save it — it's your feature. The
library's job ends the moment it hands you the text.

---

## 9. Common Errors

`LlmException.fromDio()` converts these automatically — just catch `LlmException`
and show `e.message`.

| Problem | Cause & Fix |
|---|---|
| **Invalid or missing API key** (401 / 403) | Re-copy the key exactly, no spaces. Local models don't need a key — leave it empty. |
| **Out of credits** (402) | Cloud account has no quota. Add credit, use a `:free` model, or switch to a local model. |
| **Model not found** (400 / 404) | The Model ID must match the provider's list exactly, including any prefix (e.g. `deepseek/deepseek-chat`, `openai/gpt-4o-mini`, `llama3`). |
| **Rate limit reached** (429) | Too many requests too fast. Wait a moment and retry. |
| **Request timed out** | Endpoint slow or unreachable. Check internet and the URL. |
| **Local Ollama won't connect** | Use `http`, not `https`. Run `ollama serve`. On Android emulator, use `http://10.0.2.2:11434/v1` (not `localhost`). |

---

## 10. Files to Share

```
lib/services/llm/llm_client.dart        # LLMClient — the universal caller (required)
lib/services/llm/llm_exception.dart     # LlmException — friendly errors (required)
lib/screens/settings/ai_model_screen.dart  # AiModelScreen — config UI (reuse as-is)
```

**Dependencies:** `dio`, `shared_preferences`.

That's the whole integration. Copy them, call `generate()`, build your feature.

---

> **Credit:** If you use this integration, add this line to your app's LLM page:
> "LLM integration pattern by Kabir Singh Khanuja (GSoC 2026, LG) 
> github.com/kabirkhanuja/lg-ai-tour-director"

---

*Built for GSoC 2026 · Liquid Galaxy · by Kabir Singh Khanuja. Reuse it, credit
it, and link this file from your own app's LLM integration page.*
