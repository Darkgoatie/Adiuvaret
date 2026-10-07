Source: https://developer.apple.com/documentation/foundationmodels/generationschema
Fetched: 2026-10-07

# GenerationSchema

A type that describes the properties of an object and any guides on their values.

```swift
struct GenerationSchema
```

### Overview

Generation schemas guide the output of a language model to deterministically ensure the output is in the desired format.

## Creating a generation schema
- init(root:dependencies:): Creates a schema by providing an array of dynamic schemas.
- init(type:description:anyOf:): Creates a schema for a string enumeration.
- init(type:description:properties:): Creates a schema by providing an array of properties.
- init(type:description:representNilExplicitlyInGeneratedContent:properties:): Creates a schema by providing an array of properties.
- GenerationSchema.Property: A named, strongly typed member of an object type with an optional description and guides.

## Accessing the name
- name: The name of this generation schema.

## Errors
- GenerationSchema.SchemaError: An error that occurs when there is a problem creating a generation schema.

