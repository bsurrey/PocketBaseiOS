//
//  RealtimeQuery.swift
//  PocketBase
//
//  Created by Brianna Zamora on 8/18/24.
//

import PocketBase
import SwiftUI
import Collections

@MainActor
@propertyWrapper
public struct RealtimeQuery<T: BaseRecord>: DynamicProperty
where T.EncodingConfiguration == RecordCollectionEncodingConfiguration {
    
    public init(
        page: Int = 0,
        perPage: Int = 30,
        shouldPage: Bool = true,
        sort: [SortDescriptor<T>] = [SortDescriptor(\.created, order: .reverse)]
    ) {
        self.page = page
        let configuration = Configuration(
            perPage: perPage,
            shouldPage: shouldPage,
            sort: sort
        )
        self.configuration = configuration
        self.records = []
    }
    
    @Environment(\.pocketbase) private var pocketbase

    @State private var records: [T]
    @State private var page: Int
    @State private var nextPage: Int?
    
    private var realtime: Realtime {
        pocketbase.realtime
    }
    
    private var collection: RecordCollection<T> {
        pocketbase.collection(T.self)
    }
    
    /// The records exposed to the view
    public var wrappedValue: [T] {
        records
    }
    
    @State private var mostRecentError: Error?
    
    /// The coodinator object that enables an interface with the realtime query from the view.
    public var projectedValue: Coordinator {
        Coordinator(
            error: mostRecentError
        ) {
            await start()
        } load: {
            await load()
        }
    }
    
    func start() async {
        self.mostRecentError = nil
        if records.isEmpty {
            await load()
        }
        do {
            try await collection.subscribe() { event in
                let record = event.value
                switch event.action {
                case .create:
                    await insert(record)
                case .update:
                    await update(record)
                case .delete:
                    await remove(record)
                }
            }
        } catch {
            self.mostRecentError = error
        }
    }
    
    func load() async {
        do {
            self.mostRecentError = nil
            let response = try await getRecords()
            page = response.page
            if configuration.shouldPage {
                if response.page < response.totalPages {
                    nextPage = response.page + 1
                } else {
                    nextPage = nil
                }
            }
            guard let updatedRecords = records.applying(response.items.difference(from: records)) else {
                return
            }
            records = updatedRecords
        } catch {
            self.mostRecentError = error
        }
    }
    
    @State
    private var configuration: RealtimeQuery<T>.Configuration

    /// Set the messages via the main thread.
    func set(_ response: RecordCollection<T>.ListResponse) {
        self.records = response.items
    }
    
    /// Append a record to the stored records via the main thread.
    func insert(_ record: T) {
        records.append(record)
        sort()
    }
    
    /// Remove a record from the stored records via the main thread
    func remove(_ record: T) {
        records[record.id] = nil
    }
    
    func update(_ record: T) {
        guard let existingIndex = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[existingIndex] = record
        sort()
    }
    
    func sort() {
        records = records.sorted(using: configuration.sort)
    }
    
    func getRecords() async throws -> RecordCollection<T>.ListResponse {
        try await collection.list(
            page: page,
            perPage: configuration.perPage,
            sort: configuration.sort
        )
    }
}

extension Array where Element: Record, Index == Int {
    subscript(id: String) -> Element? {
        get {
            first(where: { $0.id == id })
        }
        set {
            guard let index = firstIndex(where: { $0.id == id }) else {
                return
            }
            if let newValue {
                self[index] = newValue
            } else {
                self.remove(at: index)
            }
        }
    }
}
extension RealtimeQuery {
    public struct Configuration : Sendable{
        public var perPage: Int
        public var shouldPage: Bool
        public var sort: [SortDescriptor<T>]
        
        public init(
            perPage: Int,
            shouldPage: Bool,
            sort: [SortDescriptor<T>]
        ) {
            self.perPage = perPage
            self.shouldPage = shouldPage
            self.sort = sort
        }
    }
}

extension RealtimeQuery {
    public struct Coordinator: Sendable {
        public var error: (any Error)?
        public var start: @Sendable () async -> Void
        public var load: @Sendable () async -> Void
    }
}
