Source: https://developer.apple.com/documentation/foundationmodels/generable
Fetched: 2026-10-07

# Generable

A type that the model uses when responding to prompts.

```swift
protocol Generable : ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent
```

### Overview

Annotate your Swift structure or enumeration with the `@Generable` macro to allow the model to respond to prompts by generating an instance of your type. Use the `@Guide` macro to provide natural language descriptions of your properties, and programmatically control the values that the model can generate.

```swift
@Generable
struct SearchSuggestions {
    @Guide(description: "A list of suggested search terms.", .count(4))
    var searchTerms: [SearchTerm]
    @Generable
    struct SearchTerm {
        // Use a generation identifier for data structures the framework generates.
        var id: GenerationID
        @Guide(description: "A two- or three- word search term, like 'Beautiful sunsets'.")
        var searchTerm: String
    }
}
```

For every Generable type in a request, the framework converts its type and format information to a JSON schema and provides it to the model. This contributes to the available context window size. If the LanguageModelSession exceeds the available context size, it throws contextSizeExceeded(_:). To reduce the size of your generable type:

- Reduce the complexity of your Generable type by evaluating whether properties are necessary to complete the task.
- Give your properties short and clear names.
- Use Guide(description:) on properties only when it improves response quality.
- Add a Guide(description:_:) with maximumCount(_:) to reduce token usage.

If the Generable type includes properties with clear names the model may have all it needs to generate your type, eliminating the need of Guide(description:). For more information on managing the context window size, see managing-the-context-window.

## Creating a Generable type
- Generable(description:): 
- Generable(description:representNilExplicitlyInGeneratedContent:): 
- Generable(name:description:representNilExplicitlyInGeneratedContent:): 

## Creating a guide
- Guide(description:): 
- Guide(description:_:): 
- GenerationGuide: Guides that control how values are generated.

## Getting the schema
- generationSchema: An instance of the generation schema.

## Converting to partially generated
- asPartiallyGenerated(): Returns the partially generated representation of the current instance.
- PartiallyGenerated: A representation of partially generated content

