import SwiftData

enum ListenHereSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Memory.self,
            Journal.self,
            PhotoEditRecipe.self,
            AudioEditRecipe.self,
            MemoryPresentationRecipe.self,
            MemoryDecorationPlacement.self,
        ]
    }
}

enum ListenHereMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ListenHereSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
