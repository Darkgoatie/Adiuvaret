Source: https://developer.apple.com/documentation/swiftdata
Fetched: 2026-10-07

## SwiftData

Write your model code declaratively to add managed persistence and efficient model fetching.

### Overview

Combining Core Data’s proven persistence technology and Swift’s modern concurrency features, SwiftData enables you to add persistence to your app quickly, with minimal code and no external dependencies. Using modern language features like macros, SwiftData enables you to write code that is fast, efficient, and safe, enabling you to describe the entire model layer (or object graph) for your app. The framework handles storing the underlying model data, and optionally, syncing that data across multiple devices.

SwiftData has uses beyond persisting locally created content. For example, an app that fetches data from a remote web service might use SwiftData to implement a lightweight caching mechanism and provide limited offline functionality.

SwiftData is unintrusive by design and supplements your app’s existing model classes. Attach the  macro to any model class to make it persistable. Customize the behavior of that model’s properties with the  and  macros. Use the  class to insert, update, and delete instances of that model, and to write unsaved changes to disk.

To display models in a SwiftUI view, use the  macro and specify a predicate or fetch descriptor. SwiftData performs the fetch when the view appears, and tells SwiftUI about any subsequent changes to the fetched models so the view can update accordingly. You can access the model context in any SwiftUI view using the  environment value, and specify a particular model container or context for a view with the  and  view modifiers.

## Model()

Converts a Swift class into a stored model that’s managed by SwiftData.

```swift
@attached(member, conformances: Observable, PersistentModel, Sendable, names: named(_$backingData), named(persistentBackingData), named(schemaMetadata), named(init), named(_$observationRegistrar), named(_SwiftDataNoType), named(access), named(withMutation)) @attached(memberAttribute) @attached(extension, conformances: Observable, PersistentModel, Sendable) macro Model()
```

### Overview

Annotate your model classes with the `@Model` macro to make them persistable. At build time, the macro expands to provide conformance to the  and  protocols.

```swift
@Model
class RemoteImage {
    var sourceURL: URL
    var data: Data
    
    init(sourceURL: URL, data: Data = Data()) {
        self.sourceURL = sourceURL
        self.data = data
    }
}
```

For more information about defining models, see .

## ModelContainer

An object that manages an app’s schema and model storage configuration.

```swift
class ModelContainer
```

### Overview

A model container mediates between its associated model contexts and your app’s underlying persistent storage. The container manages all aspects of that storage and ensures it remains in a consistent and usable state. Whenever you run a fetch or call a context’s  method, the container performs the actual read or write of the underlying data using information from the schema you provide. This helps safeguard an app’s resources and ensures those operations happen only in an efficient and coordinated manner. Additionally, if your app’s entitlements include CloudKit, the container automatically handles syncing the persisted storage across devices. For more information about syncing model data, see .

As your app’s schema evolves, the container performs automatic migrations of the persisted model data so it remains consistent with the app’s model classes. If the aggregate changes between two versions of your schema exceed the capabilities of automatic migrations, provide the container with a  to participate in those migrations and help ensure they complete successfully.

By default, a model container makes a number of assumptions about how it configures an app’s persistent storage. If you need to customize this behavior, provide the container with one or more instances of . For example, you may want use a particular app group container or specify that the storage is ephemeral and should exist only in memory.

An app that uses SwiftData requires at least one model container. You create a container using one of the class’s initializers or the corresponding SwiftUI view modifier. Using the view modifier ensures all windows in the modified window group, or all child views of the modified view, access the same model container. Additionally, the view modifier makes an associated model context available in the SwiftUI environment, which the `Query()` macro depends on.

```swift
@main
struct RecipesApp: App {
    var body: some Scene {
        WindowGroup {
            RecipesList()
        }
        .modelContainer(for: Recipe.self)
    }
}

struct RecipesList: View {
    @Query private var recipes: [Recipe]
    
    var body: some View {
        List(recipes) { RecipeRowView($0) }
    }
} 

```

## ModelConfiguration

A type that describes the configuration of an app’s schema or specific group of models.

```swift
struct ModelConfiguration
```

## Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

```swift
@attached(peer) macro Relationship(_ options: Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule = .nullify, minimumModelCount: Int? = 0, maximumModelCount: Int? = 0, originalName: String? = nil, inverse: AnyKeyPath? = nil, hashModifier: String? = nil)
```

### Overview

If one or more of a model’s properties represent relationships between their containing model and another model, annotate those properties with the `@Relationship` macro. This enables SwiftData to enforce those relationships at runtime — including what happens if you delete related data – as well as write any associated metadata to the persistent storage so the relationships exist across app launches.

In the following example, a remote image may belong to a category, and a category can contain zero, one, or more images.

```swift
@Model
class RemoteImage {
    @Attribute(.unique) var sourceURL: URL
    @Relationship(inverse: \Category.images) var category: Category?
    var data: Data

    init(sourceURL: URL, data: Data = Data()) {
        self.sourceURL = sourceURL
        self.data = data
    }
}

@Model
class Category {
    @Attribute(.unique) var name: String
    @Relationship var images = [RemoteImage]()

    init(name: String) {
        self.name = name
    }
}
```

For more information about defining relationships between models, see .

## ModelContext

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

```swift
class ModelContext
```

### Overview

A model context is central to SwiftData as it’s responsible for managing the entire lifecycle of your persistent models. You use a context to insert new models, track and persist changes to those models, and to delete those models when you no longer need them. A context understands your app’s schema but doesn’t know about any individual models until you tell it to fetch some from the persistent storage or populate it with new models. Afterwards, any changes made to those models exist only in memory until the context implicitly writes them to the persistent storage, or you manually invoke . For more information about implicit writes, see .

If your app’s schema describes relationships between models, you don’t need to manually insert each model into the context when you first create them. Instead, create the graph of related models and insert only the graph’s root model into the context. The context recognizes the hierarchy and automatically handles the insertion of the related models. The same behavior applies even if the graph contains both new and existing models.

A model context depends on a model container for knowledge about your app’s schema and persistent storage. After you attach a container to your app’s window group or view hierarchy, an associated context becomes available in the SwiftUI environment. This context is bound to the main actor and the framework configures the context to implicitly save future model changes. The  macros use the same context to perform their fetches.

```swift
struct LastModifiedView: View {
    @Environment(\.modelContext) private var modelContext

}
```

After you establish access to a model context, use that context’s  and  methods to add and remove models. You can also delete several models at once using . There isn’t a corresponding method to update a model because the context automatically tracks all changes to its known models. Use the  property to determine if the context has unsaved changes, and call  to discard any pending inserts and deletes and any restore changed models to their most recent saved state.

Although you fetch models primarily with the `Query()` macro (and its variants), you can use a model context to perform almost identical fetches. For example, use the  and  methods to retrieve all models of a certain type that match a set of criteria. And use  to determine the number of models that match some criteria without the overhead of fetching the models themselves. If you need to be able to identify models that match some criteria but don’t require all of the associated data, use  and  to retrieve only those models’ persistent identifiers.

A model context posts a  notification before it attempts a save operation, and a  notification immediately after that operation succeeds. Subscribe to one, or both, of these notifications if your app needs to be aware of these events. The `didSave` notification provides additional information about any inserted, updated, and deleted models.

```swift
struct LastModifiedView: View {
    @Environment(\.modelContext) private var context
    @State private var lastModified = Date.now
    
    private var didSavePublisher: NotificationCenter.Publisher {
        NotificationCenter.default
            .publisher(for: ModelContext.willSave, object: context)
    }
    
    var body: some View {
        Text(lastModified.formatted(date: .abbreviated, time: .shortened))
            .onReceive(didSavePublisher) { _ in
                lastModified = Date.now
            }
    }
}
```

## FetchDescriptor

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

```swift
struct FetchDescriptor<T> where T : PersistentModel
```

### Overview

Use a fetch descriptor to capture the criteria necessary to select, and optionally sort, a specific collection of models from your app’s persistent storage. A fetch descriptor retrieves only a single type of persistent model, and relies on type inference to determine the appropriate type. However, you can configure a fetch descriptor to prefetch related models of different types using the  property.

To fetch a collection of models, first create a fetch descriptor and specify a predicate and one or more sort descriptors. The predicate describes the attributes to filter by and the constraints to apply to those attributes. If you don’t specify a predicate, the fetch returns all models of the inferred type. You can further tweak a fetch by limiting the number of models it returns, or indicating whether the fetch evaluates any unsaved changes when it selects the models to return. After configuring the fetch descriptor, pass it to the model context’s  method to run the fetch.

```swift
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.isFavorite == true },
    sortBy: [
        .init(\.createdAt)
    ]
)
descriptor.fetchLimit = 10

let favoriteRecipes = try modelContext.fetch(descriptor)
```

If you’re displaying the fetched models in a SwiftUI view, use the descriptor with the  macro instead.

```swift
struct FavoriteRecipesList: View {
    static var fetchDescriptor: FetchDescriptor<Recipe> {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [
                .init(\.createdAt)
            ]
        )
        descriptor.fetchLimit = 10
        return descriptor
    }

    @Query(FavoriteRecipesList.fetchDescriptor) private var favoriteRecipes: [Recipe]
    
    var body: some View {
        List(favoriteRecipes) { RecipeRowView($0) }
    }
} 
```

## Attribute(_:originalName:hashModifier:)

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

```swift
@attached(peer) macro Attribute(_ options: Schema.Attribute.Option..., originalName: String? = nil, hashModifier: String? = nil)
```

### Overview

The framework’s default behavior for managing a model class’s stored properties is suitable for most use cases. However, if you need to alter the persistence behavior of a particular property, annotate it with the `@Attribute` macro. For example, you may want to avoid conflicts in your model data by specifying that an attribute’s value is unique across all instances of that model.

```swift
@Model
class RemoteImage {
    @Attribute(.unique) var sourceURL: URL
    var data: Data
    
    init(sourceURL: URL, data: Data = Data()) {
        self.sourceURL = sourceURL
        self.data = data
    }
}
```
