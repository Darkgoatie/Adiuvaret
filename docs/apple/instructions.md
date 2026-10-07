Source: https://developer.apple.com/documentation/foundationmodels/instructions
Fetched: 2026-10-07

# Instructions

Details you provide that define the model’s intended behavior on prompts.

```swift
struct Instructions
```

### Overview

You typically provide instructions to define the role and behavior of the model. In the code below, the instructions specify that the model replies with topics rather than, for example, a recipe:

```swift
let instructions = """
    Suggest related topics. Keep them concise (three to seven words) and make sure they \
    build naturally from the person's topic.
    """

let session = LanguageModelSession(instructions: instructions)

let prompt = "Making homemade bread"
let response = try await session.respond(to: prompt)
```

Don’t include untrusted content in instructions: the model is typically trained to obey instructions over any commands it receives in prompts. For more on how instructions impact generation quality and safety, see improving-the-safety-of-generative-model-output.

All input to the model contributes tokens to the context window of the LanguageModelSession — including the Instructions, Prompt, Tool, and Generable types, and the model’s responses. If your session exceeds the available context size, it throws  contextSizeExceeded(_:).

Instructions can consume a lot of tokens that contribute to the context window size. To reduce your instruction size:

- Write shorter instructions to save tokens.
- Provide only the information necessary to perform the task.
- Use concise and imperative language instead of indirect or jargon that the model might misinterpret.
- Aim for one to three paragraphs instead of including a significant amount of background information, policy, or extra content.

For more information on managing the context window size, see managing-the-context-window.

## Creating instructions
- init(_:): Creates instructions from the content of a builder closure.
- InstructionsBuilder: A type that represents an instructions builder.
- InstructionsRepresentable: A type that can be represented as instructions.

