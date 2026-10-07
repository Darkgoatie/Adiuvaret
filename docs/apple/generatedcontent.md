Source: https://developer.apple.com/documentation/foundationmodels/generatedcontent
Fetched: 2026-10-07

# GeneratedContent

A type that represents structured, generated content.

```swift
struct GeneratedContent
```

### Overview

Generated content may contain a single value, an array, or key-value pairs with unique keys.

## Creating generated content
- init(_:): Creates generated content from another value.
- init(_:id:): Creates content that contains a single value with a custom generation identifier.
- init(elements:id:): Creates content representing an array of elements you specify.
- init(properties:id:): Creates generated content representing a structure with the properties you specify.
- init(properties:id:uniquingKeysWith:): Creates generated content from key-value pairs, resolving duplicate keys with a combining closure.
- init(json:): Creates equivalent content from a JSON string.
- init(kind:id:): Creates content with the specified kind and generation identifier.
- GeneratedContent.ParsingError: A failure that occurs when a string cannot be parsed into generated content.

## Accessing the content
- kind: The representation of the generated content.
- GeneratedContent.Kind: A representation of the different types of content that can be stored in generated content.
- value(_:): Reads a top level, concrete partially generable type from a named property.
- value(_:forProperty:): Reads a concrete generable type from a named property.
- isComplete: A Boolean value that indicates whether the generated content is complete.
- generatedContent: A representation of this instance.
- jsonString: A JSON string representation of the generated content.
- debugDescription: A string representation for the debug description.

## Identifying a generation
- id: A unique id that is stable for the duration of a generated response.
- GenerationID: A unique identifier that is stable for the duration of a response, but not across responses.

## Default Implementations
- ConvertibleFromGeneratedContent Implementations: 
- ConvertibleToGeneratedContent Implementations: 
- CustomDebugStringConvertible Implementations: 

