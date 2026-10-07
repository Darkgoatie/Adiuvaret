# Apple official documentation (offline copies)

Source of truth for all work with the on-device model. Fetched 2026-10-07 from developer.apple.com/tutorials/data/documentation/foundationmodels/* (the JSON behind the doc pages). Re-fetch when Xcode or iOS updates; the model has three versions (iOS 26.0-26.3, 26.4, 27.0).

Rule: before writing FoundationModels code, read the relevant page here and cite it in the decision or task. Do not rely on memory.

Key pages: managing-the-context-window, expanding-generation-with-tool-calling, generating-swift-data-structures-with-guided-generation, systemlanguagemodel, languagemodelsession, tool, prompting-an-on-device-foundation-model, improving-the-safety-of-generative-model-output, updating-prompts-for-new-model-versions, analyzing-the-runtime-performance-of-your-foundation-models-app.

Doc/SDK mismatch to resolve on device: docs name the error contextSizeExceeded and the type LanguageModelError; the iOS 26.5 SDK on the VM has LanguageModelSession.GenerationError.exceededContextWindowSize. The docs may describe the iOS 27 SDK. Check which one the shipping target needs.
