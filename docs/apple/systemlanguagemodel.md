Source: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
Fetched: 2026-10-07

# SystemLanguageModel

An on-device Apple Foundation Model capable of text generation tasks.

```swift
final class SystemLanguageModel
```

### Overview

The `SystemLanguageModel` refers to the on-device text foundation model that powers Apple Intelligence. Use default to access the base version of the model and perform general-purpose text generation tasks. To access a specialized version of the model, initialize the model with UseCase to perform tasks like contentTagging. Apple periodically updates `SystemLanguageModel` in routine OS updates to improve the on-device model’s abilities and performance. Currently, there are 3 model versions that align with:

- iOS, iPadOS, macOS, and visionOS 26.0 - 26.3
- iOS, iPadOS, macOS, visionOS 26.4
- iOS, iPadOS, macOS, and visionOS 27.0

For more information about how model versions affect your app, see updating-prompts-for-new-model-versions.

Before you use the model, you need to verify its availability. Model availability depends on whether the device and region supports Apple Intelligence. For a list of supported devices, see .

Use Availability-swift.enum to change what your app shows to people based on the availability condition:

```swift
struct GenerativeView: View {
    // Create a reference to the system language model.
    private var model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            // Show your intelligence UI.
        case .unavailable(.deviceNotEligible):
            // Show an alternative UI.
        case .unavailable(.modelNotReady):
            // The model isn't ready because it's downloading or because
            // of other system reasons.
        case .unavailable(let other):
            // The model is unavailable for an unknown reason.
        }
    }
}
```

## Getting the default model
- default: The base version of the model.

## Creating a model for a use case
- init(useCase:guardrails:): Creates a system language model instance for a specific use case.
- SystemLanguageModel.UseCase: A type that represents the use case for prompting.
- SystemLanguageModel.Guardrails: A set of controls that flag sensitive content from model input and output.

## Accessing the model variant
- variant: The variant of the on-device model backing this instance.
- SystemLanguageModel.Variant: The variant of an on-device model.

## Checking model availability
- isAvailable: A Boolean value that indicates whether the system is entirely ready.
- availability: The availability of the language model.
- SystemLanguageModel.Availability: The availability status for a specific system language model.

## Inspecting model capabilities
- contextSize: The maximum context size in tokens that the model supports.
- supportedLanguages: Languages that the model supports.
- supportsLocale(_:): Returns a Boolean value that indicates whether the given locale is supported by the model.

## Counting tokens
- tokenCount(for:): Returns the token count for the specified instructions.

## Handling a language model error
- SystemLanguageModel.Error: An error specific to the on-device system language model.

## Default Implementations
- LanguageModel Implementations: 

