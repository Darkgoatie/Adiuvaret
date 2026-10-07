Source: https://developer.apple.com/documentation/foundationmodels/tool
Fetched: 2026-10-07

# Tool

A tool that a model can call to gather information at runtime or perform side effects.

```swift
protocol Tool<Arguments, Output> : Sendable
```

### Overview

Tool calling gives the model the ability to call your code to incorporate up-to-date information like recent events and data from your app. A tool includes a name and a description that the framework puts in the prompt to let the model decide when and how often to call your tool.

A `Tool` defines a call(arguments:) method that takes arguments that conforms to ConvertibleFromGeneratedContent, and returns an output of any type that conforms to PromptRepresentable, allowing the model to understand and reason about in subsequent interactions. Typically, Output is a `String` or any Generable types.

```swift
struct FindContacts: Tool {
    let name = "findContacts"
    let description = "Finds a specific number of contacts"

    @Generable
    struct Arguments {
        @Guide(description: "The number of contacts to get", .range(1...10))
        let count: Int
    }

    func call(arguments: Arguments) async throws -> [String] {
        var contacts: [CNContact] = []
        // Fetch a number of contacts using the arguments.
        let formattedContacts = contacts.map {
            "\($0.givenName) \($0.familyName)"
        }
        return formattedContacts
    }
}
```

Tools must conform to Sendable so the framework can run them concurrently. If the model needs to pass the output of one tool as the input to another, it executes back-to-back tool calls.

You control the life cycle of your tool, so you can track the state of it between calls to the model. For example, you might store a list of database records that you don’t want to reuse between tool calls.

Prompting the model with tools contributes to the available context window size. When you provide a tool in your generation request, the framework puts the tool definitions — name, description, parameter information — in the prompt so the model can decide when and how often to call the tool. After calling your tool, the framework returns the tool’s output back to the model for further processing. For more information on managing the context window size, see managing-the-context-window.

## Calling a tool
- call(arguments:): Performs the tool’s action when a language model wants to use this tool.
- Arguments: The arguments that this tool should accept.
- Output: The output that this tool produces for the language model to reason about in subsequent interactions.

## Inspecting a tool
- name: A unique name for the tool.
- description: A natural language description of when and how to use the tool.
- parameters: A schema for the parameters this tool accepts.
- includesSchemaInInstructions: A Boolean value that indicates whether the framework includes this tool’s definition in the session’s instructions.
- Tool.SessionProperty: A property wrapper that provides access to a session property from within a tool.

