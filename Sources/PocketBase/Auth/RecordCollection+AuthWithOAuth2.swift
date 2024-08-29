//
//  File.swift
//  PocketBase
//
//  Created by Brianna Zamora on 8/5/24.
//

import Foundation

public extension RecordCollection where T: AuthRecord {
    @Sendable
    func authWithOAuth2<CreateData: Encodable>(
        provider: String,
        code: String,
        codeVerifier: String,
        redirectUrl: URL,
        createData: CreateData,
        expand: [String] = [],
        fields: [String] = []
    ) async throws -> AuthResponse<T> {
        let response: AuthResponse<T> = try await post(
            path: PocketBase.collectionPath(collection) + "auth-with-oauth2/",
            query: {
                var query: [URLQueryItem] = []
                if !expand.isEmpty {
                    query.append(URLQueryItem(name: "expand", value: expand.joined(separator: ",")))
                }
                if !fields.isEmpty {
                    query.append(URLQueryItem(name: "fields", value: fields.joined(separator: ",")))
                }
                return query
            }(),
            headers: headers,
            body: JSONSerialization.data(
                withJSONObject: [
                    "provider": provider,
                    "code": code,
                    "codeVerifier": codeVerifier,
                    "redirectUrl": redirectUrl,
                    "createData": createData
                ]
            )
        )
        try pocketbase.authStore.set(response: response)
        return response
    }
}
