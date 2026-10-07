Source: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:options:)
Fetched: 2026-10-07

# streamResponse(to:options:)

Produces a response stream to a prompt.

```swift
final func streamResponse(to prompt: Prompt, options: GenerationOptions = GenerationOptions()) -> sending LanguageModelSession.ResponseStream<String>
```

### Return Value

A response stream that produces aggregated tokens.

### Discussion

> If running in the background, use the non-streaming respond(to:options:)-6a2gb method to reduce the likelihood of encountering rateLimited(_:) errors.

