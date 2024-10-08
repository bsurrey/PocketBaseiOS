//
//  PocketBase+AuthRefresh.swift
//  PocketBase
//
//  Created by Brianna Zamora on 8/5/24.
//

import Foundation

public extension RecordCollection where T: AuthRecord {
    @Sendable
    @discardableResult
    func authRefresh() async throws -> AuthResponse<T> {
        do {
            let response: AuthResponse<T> = try await post(
                path: PocketBase.collectionPath(collection) + "auth-refresh",
                query: {
                    var query: [URLQueryItem] = []
                    if !T.relations.isEmpty {
                        query.append(URLQueryItem(name: "expand", value: T.relations.keys.joined(separator: ",")))
                    }
                    return query
                }(),
                headers: headers
            )
            try pocketbase.authStore.set(response)
            return response
        } catch {
            pocketbase.authStore.clear()
            throw error
        }
    }
}
