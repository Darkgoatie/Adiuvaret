Source: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:)
Fetched: 2026-10-07

# respond(to:options:)

Produces a response to a prompt.

```swift
@discardableResult nonisolated(nonsending) final func respond(to prompt: Prompt, options: GenerationOptions = GenerationOptions()) async throws -> LanguageModelSession.Response<String>
```

### Return Value

A string composed of the tokens produced by sampling model output.

