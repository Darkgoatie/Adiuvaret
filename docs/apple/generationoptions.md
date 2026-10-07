Source: https://developer.apple.com/documentation/foundationmodels/generationoptions
Fetched: 2026-10-07

# GenerationOptions

Options that control how the model generates its response to a prompt.

```swift
struct GenerationOptions
```

### Overview

Generation options determine the decoding strategy the framework uses to adjust the way the model chooses output tokens. When you interact with the model, it converts your input to a token sequence, and uses it to generate the response.

Only use maximumResponseTokens when you need to protect against unexpectedly verbose responses. Enforcing a strict token response limit can lead to the model producing malformed results or grammatically incorrect responses.

All input to the model contributes tokens to the context window of the LanguageModelSession — including the Instructions, Prompt, Tool, and Generable types, and the model’s responses. If your session exceeds the available context size, it throws contextSizeExceeded(_:). For more information on managing the context window size, see managing-the-context-window.

## Creating options
- init(samplingMode:temperature:maximumResponseTokens:): Creates generation options that control token sampling behavior.
- init(samplingMode:temperature:maximumResponseTokens:toolCallingMode:): Creates generation options that control token sampling behavior.
- init(sampling:temperature:maximumResponseTokens:): Creates generation options that control token sampling behavior.

## Configuring options
- temperature: A value that influences the confidence of the model’s response.
- sampling: A sampling strategy for how the model picks tokens when generating a response.
- samplingMode: A sampling strategy for how the model picks tokens when generating a response.
- GenerationOptions.SamplingMode: A type that defines how values are sampled from a probability distribution.
- toolCallingMode: The tool calling requirements.
- GenerationOptions.ToolCallingMode: A value that describes how the model uses tools.
- maximumResponseTokens: The maximum number of tokens the model is allowed to produce in its response.

