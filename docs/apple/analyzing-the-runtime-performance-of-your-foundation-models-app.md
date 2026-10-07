Source: https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
Fetched: 2026-10-07

# Analyzing the runtime performance of your Foundation Models app

Measure how prompts, responses, and tool calls affect token consumption and response times in Instruments.

### Overview

The Foundation Models instrument surfaces the prompts your app sends to the model, the tools the model calls, where your app spends time, and how your app consumes tokens — all of which helps you understand what your app is doing and when. Depending on the model provider you use, cost can be a factor to consider.

Use the breakdown of token usage to make informed decisions about cached tokens versus generated tokens. By analyzing your app’s model usage patterns, you can identify bottlenecks and apply targeted optimizations that help you reduce context size and improve the quality of your intelligent features. The instrument also provides insight into:

- The instructions, prompt, and response that form each request to the model.
- Where and how the model invokes the custom tools your app provides, along with how long the tool takes to run and its output.
- A per-session breakdown that contains details about how long every request took and how the session consumed tokens through each step.

Together, these insights show how your app interacts with the model and help you identify where to apply optimizations.

### Launch and configure Instruments for recording

Instruments includes a default template you use when analyzing your app’s interactions with the Foundation Models framework. Start by opening Instruments from your Xcode project:

- In Xcode, choose Product > Profile.
- In the Template Selection window, select the Foundation Models template.
- Click Choose.



### Record app interactions to gather data

Before reviewing your app’s performance, check that your development device isn’t under thermal pressure or busy with other work. This helps you ensure that the device is in a good performance state, which can influence your analysis. When you record a run, use your app as normal and focus on interactions that perform requests to the model. Begin gathering data by clicking the Record Trace button in the upper-left corner or by choosing File > Record Trace:



Because a recording captures and stores all Foundation Models prompts and responses in an unencrypted form, Instruments presents an alert when you begin recording. The captured data can include sensitive information, so handle trace files accordingly, and use this feature in a manner consistent with the . After starting the recording, perform actions that interact with the model, wait for the responses to complete, then click Stop to end recording.

### Get to know the instrument

The primary timeline shows events the instrument measures. The width of each component on the timeline indicates latency.



The Foundation Models track appears in your timeline, with several lanes that provide insight into your recording:

Choose View > Zoom > Zoom in to review activity at a more granular time scale.

The Inspector shows several details for the request, like the instructions, prompt, response, duration, and token metrics. To view a detailed breakdown of the duration of a request:

- Click the Foundation Models instrument.
- Select View > Detail Area > Tree.
- Select the Model Inference you want to analyze.
- If the inspector isn’t visible, choose View > Show Inspector.



The Inspector shows a breakdown of duration details:

### Monitor token usage

When you prompt a language model, the model breaks down the input text into small fragments called tokens. Each token is typically a word or a piece of a word. The token count includes instructions, prompts, and outputs for a session instance. If your session processes a large number of tokens that exceed the context window, the framework throws the error contextSizeExceeded(_:). For more information on managing the context window size, see managing-the-context-window.

More output tokens generally require more processing time. Additionally, processing time depends on the task you perform. For example, summarizing a document requires much less processing time than generating a new article, because it’s mostly a reading task for the model.

The cost of text varies between characters and symbols versus discrete words. For example, the word `Sourdough` might be one token, but a phone number like `+1-(408)-555-0123` might use over ten tokens because of the characters and symbols.

High token counts affect both initial processing time and memory usage. Use the inspector to view a detailed breakdown of token metrics for the request:



The Inspector shows a variety of token metrics:

The cache hit rate is the percentage of input tokens the system serves from the prefix cache, and depends on the model provider you use. For more information about caching, see optimizing-key-value-caching-in-language-model-sessions.

### Reduce token consumption

A lower token count improves performance and helps you stay within context limits.

The `includeSchemaInPrompt` parameter in streamResponse(generating:includeSchemaInPrompt:options:prompt:) tells the framework to include information about Generable types in your prompts before processing the request. Doing so improves the output quality, but requires that the model consumes more input tokens. If you’ve already made a similar request or provided examples in your instructions, you can exclude the schema in subsequent requests. Excluding the schema removes redundant schema information and can save hundreds of tokens per request. To further optimize token usage, consider whether you need nested Generable types in a parent type. The model needs more context to handle nested Generable schema details.

When you no longer need the schema data for your session, set `includeSchemaInPrompt` to `false`:

```swift
do {
    // Stream a response from the model and exclude the schema for your 
    // custom type.
    for try await partial in session.streamResponse(to: myPrompt,
                                                    generating: MyCustomItinerary.self,
                                                    includeSchemaInPrompt: false) {
        // Handle the partial result.
    }
} catch {
    // Handle the error that the method throws.
}
```

After you make this change, record a new trace and use the Inspector panel to check that the token counts remain within your intended budget. A lower total token count translates to faster initial processing. For more context window management techniques, see managing-the-context-window.

