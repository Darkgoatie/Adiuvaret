Source: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/toolcallerror
Fetched: 2026-10-07

# LanguageModelSession.ToolCallError

An error that occurs while a language model is calling a tool.

```swift
struct ToolCallError
```

## Creating a tool call error
- init(tool:underlyingError:): Creates a tool call error.

## Getting the tool
- tool: The tool that produced the error.

## Getting the error description
- errorDescription: A string representation of the error description.

## Getting the underlying error
- underlyingError: The underlying error that was thrown during a tool call.

## Default Implementations
- LocalizedError Implementations: 

