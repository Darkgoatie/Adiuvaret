Source: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile
Fetched: 2026-10-07

# LanguageModelSession.DynamicProfile

A dynamic profile that contains one or more profiles.

```swift
protocol DynamicProfile
```

### Overview

A dynamic profile is the top-level coordination layer that manages profiles. It determines which Profile is in an active state and allows a LanguageModelSession to switch between entirely different configurations as app state changes. A body must resolve to a single profile.

DynamicInstructions declares what content and tools the model sees, and Profile binds that content to how a single configuration runs. That configuration includes details like the model to use, temperature, reasoning level, and so on.

```swift
struct PresentationProfile: LanguageModelSession.DynamicProfile {
    // The data source for the profile.
    var isEditingImage = true
    var isEditingAnimation = false

    // Determine which profile to load based on the current state.
    var body: some LanguageModelSession.DynamicProfile {
        if isEditingImage {
            // Use the editing image profile.
        } else if isEditingAnimation {
            // Use the editing animation profile.
        } else {
            // Use the default profile.
        }
    }
}
```

Use historyTransform(_:) to perform stateless transcript transforms. This allows you to modify the transcript that’s sent to the model, but doesn’t impact the global transcript state. For example, the request might only need the last twenty entries instead of the full transcript:

```swift
Profile {
    // The instructions and tools necessary for the task.
}
.historyTransform { history in
    Array(history.suffix(20))
}
```

## Implementing a dynamic profile
- body: The content of the dynamic profile.
- Body: The type of dynamic profile that represent this profile.
- LanguageModelSession.DynamicProfile.DynamicProfile: The dynamic profile type that a dynamic profile’s body composes.
- LanguageModelSession.DynamicProfile.Profile: The profile type that a dynamic profile activates.
- LanguageModelSession.DynamicProfile.SessionProperty: A property wrapper that provides access to a session property from within a dynamic profile.

## Transforming the history
- historyTransform(_:): Applies a transformation to the history prior to invoking the model.

## Observing life cycle modifiers
- onActivate(perform:): Runs an action when this dynamic profile becomes active.
- onDeactivate(perform:): Runs an action when this dynamic profile becomes inactive.
- onPrompt(perform:): Runs an action before the model is invoked for this dynamic profile.
- onReasoning(perform:): Runs an action whenever this dynamic profile produces reasoning.
- onResponse(perform:): Runs an action after this dynamic profile produces a response.
- onToolCall(perform:): Runs an action whenever a tool is called within this dynamic profile.
- onToolOutput(perform:): Runs an action whenever a tool call output is received within this dynamic profile.

## Applying tool modifiers
- toolCallingMode(_:): Sets the tool-calling mode.

## Configuring the model
- model(_:): Sets the model.
- temperature(_:): Sets the model temperature.
- samplingMode(_:): Sets the samping mode.
- reasoningLevel(_:): Sets the reasoning level.
- maximumResponseTokens(_:): Sets the maximum response tokens.
- modifier(_:): Applies a modifier to the dynamic profile.

## Handling the error policy
- transcriptErrorHandlingPolicy(_:): Sets the policy for managing the transcript when errors occur.

