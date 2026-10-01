import Foundation
import SwiftData

@Model
final class LocalProfileRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) {
        self.key = key
        self.payload = payload
    }
}

enum ProfileSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [LocalProfileRecord.self] }
}

enum ProfileMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ProfileSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// Everything the app keeps lives in one table of key → JSON documents, so a new kind of data needs no
/// new schema version. The repository holds its container: the context alone would not keep it alive.
@MainActor
final class SwiftDataProfileRepository: ProfileRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    /// A store that lives in memory only, for tests.
    static func inMemory() throws -> SwiftDataProfileRepository {
        let schema = Schema(versionedSchema: ProfileSchemaV1.self)
        let container = try ModelContainer(for: schema, migrationPlan: ProfileMigrationPlan.self,
                                           configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                                                               cloudKitDatabase: .none)])
        return SwiftDataProfileRepository(container: container)
    }

    private func record(_ key: String) throws -> LocalProfileRecord? {
        let records = try context.fetch(FetchDescriptor<LocalProfileRecord>())
        return records.first { $0.key == key }
    }

    func loadDraft() throws -> OnboardingDraft? {
        guard let data = try record(StoreKey.draft)?.payload else { return nil }
        return try decoder.decode(OnboardingDraft.self, from: data)
    }

    func loadProfile() throws -> LocalProfile? {
        guard let data = try record(StoreKey.profile)?.payload else { return nil }
        return try decoder.decode(LocalProfile.self, from: data)
    }

    private func put(_ key: String, data: Data) throws {
        if let existing = try record(key) { existing.payload = data }
        else { context.insert(LocalProfileRecord(key: key, payload: data)) }
    }

    func saveDraft(_ draft: OnboardingDraft) throws {
        try save(draft, key: StoreKey.draft)
    }

    func discardDraft() throws {
        try remove(key: StoreKey.draft)
    }

    func complete(_ draft: OnboardingDraft, existing: LocalProfile?) throws -> LocalProfile {
        let now = Date()
        let profile = LocalProfile(id: existing?.id ?? draft.profileID,
                                   createdAt: existing?.createdAt ?? now,
                                   updatedAt: now, details: draft)
        do {
            try put(StoreKey.profile, data: encoder.encode(profile))
            if let pending = try record(StoreKey.draft) { context.delete(pending) }
            try context.save()
            return profile
        } catch {
            context.rollback()
            throw error
        }
    }
}

extension SwiftDataProfileRepository: DocumentStore {
    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        guard let data = try record(key)?.payload else { return nil }
        return try decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) throws {
        do {
            try put(key, data: encoder.encode(value))
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func remove(key: String) throws {
        do {
            if let existing = try record(key) { context.delete(existing) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func removeAll() throws {
        do {
            for existing in try context.fetch(FetchDescriptor<LocalProfileRecord>()) { context.delete(existing) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
