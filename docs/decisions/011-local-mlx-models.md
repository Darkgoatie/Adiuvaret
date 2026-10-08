# 011 Local MLX models, downloaded on request

Accepted 2026-10-07 on the user's instruction. Replaces the "MLX stays in Phase 3" default in decision 003.

## Decision

Adiuvaret can chat with eight MLX models from the mlx-community organisation on Hugging Face, in addition to Apple's built-in model:

  Gemma 3 1B (0.73 GB), Qwen3 1.7B (0.97), SmolLM3 3B (1.73), Llama 3.2 3B (1.81), Qwen3 4B Instruct 2507 (2.26),
  Gemma 3 4B (3.40), Gemma 4 E2B (3.55), Gemma 4 E4B (5.15)

## Exception to "no outbound model traffic"

The user approved downloads from mlx-community repositories on huggingface.co. Rules:
  - A download starts only when the user taps Download (after a license sheet for Gemma and Llama models).
  - Only model files are fetched. No chat text, prompts or identifiers are sent anywhere.
  - Everything else stays on the phone. No cloud inference, no API keys.

## How it works

  - `Packages/ModelLibrary`: the catalog, memory-fit check and the think-tag filter. Pure logic, tested on the VM.
  - `App/Models/MLXRuntime.swift`: downloads with swift-huggingface into Application Support/Models (excluded from backup,
    not purged by iOS) and loads one model at a time through mlx-swift-lm 3.32.x.
  - `App/Models/ModelSettings.swift`: installed models, the active model, download progress and deletion.
  - `App/Models/MLXChatService.swift`: chat with a downloaded model. Same `ChatService` protocol as the Apple one.
  - `App/Models/ModelsView.swift`: the Models screen under Advanced.
  - The chat header shows the model name with a menu to switch. Switching keeps the messages; the new model gets the
    last 12 as history. The model is saved per chat (ChatRecord.modelID) and restored at launch. If a model is deleted,
    chats that used it fall back to Apple.

## Limits (Stage 1)

  - MLX models are chat only. The tool router and the calendar and reminder tools run on the Apple model, because small
    open models have no verified tool-call path yet. The chat says so in its instructions.
  - Memory: each model shows a warning when its weights plus cache would use most of the memory iOS lets the app use.
    The check uses os_proc_available_memory. No increased-memory entitlement is requested yet; the larger Gemma 4 model
    may still fail and needs a device test.
  - MLX cannot run in the simulator or on the Intel VM. Compile checks run on the GitHub Xcode 27 runner; behaviour is
    checked on the phone.
  - Models with a think step have their reasoning hidden (ThinkFilter). The reply shows only the answer.

## Open

  - Real speed and memory per model on the iPhone 18 Pro, from the diagnostics log (model load, first token, reply done).
  - Whether tools can run on the best open model (Qwen3 4B) through mlx-swift-lm's tool-call support.
  - Whether to request the increased-memory-limit entitlement.
