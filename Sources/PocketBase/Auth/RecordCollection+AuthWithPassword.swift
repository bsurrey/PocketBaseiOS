//
//  PocketBase+AuthWithPassword.swift
//  PocketBase
//
//  Created by Brianna Zamora on 8/5/24.
//

import Foundation

public extension RecordCollection where T: AuthRecord {
    /// The easiest way to authenticate your app users is with their username/email and password.
    ///
    /// You can customize the supported authentication options from your Auth collection configuration (including disabling all auth options).
    /// - Parameters:
    ///   - identity: <#identity description#>
    ///   - password: <#password description#>

    /// - Returns: <#description#>
    @Sendable
    @discardableResult
    func authWithPassword(
        _ identity: String,
        password: String
    ) async throws -> AuthResponse<T> {
        let response: AuthResponse<T> = try await post(
            path: PocketBase.collectionPath(collection) + "auth-with-password",
            query: {
                var query: [URLQueryItem] = []
                if !T.relations.isEmpty {
                    query.append(URLQueryItem(name: "expand", value: T.relations.keys.joined(separator: ",")))
                }
                return query
            }(),
            headers: headers,
            body: AuthWithPasswordBody(identity: identity, password: password)
        )
        try pocketbase.authStore.set(response)
        return response
    }
}

struct AuthWithPasswordBody: EncodableWithConfiguration {
    func encode(to encoder: any Encoder, configuration: RecordCollectionEncodingConfiguration) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity, forKey: .identity)
        try container.encode(password, forKey: .password)
    }
    
    enum CodingKeys: String, CodingKey {
        case identity
        case password
    }
    
    typealias EncodingConfiguration = RecordCollectionEncodingConfiguration
    
    var identity: String
    var password: String
}
