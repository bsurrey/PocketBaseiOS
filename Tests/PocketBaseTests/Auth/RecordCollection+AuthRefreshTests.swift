//
//  RecordCollection+AuthRefreshTests.swift
//  PocketBase
//
//  Created by Brianna Zamora on 9/21/24.
//

import Testing
@testable import PocketBase

struct RecordCollection_AuthRefreshTests {
    static let identityLogin = RecordCollection<Tester>.AuthMethod
        .identity(
            username,
            password: password
        )
    
    static let oauthLogin = RecordCollection<Tester>.AuthMethod
        .oauth(
            OAuthProvider(
                name: "fake",
                state: "fake",
                codeVerifier: "fake",
                codeChallenge: "fake",
                codeChallengeMethod: "fake",
                authUrl: URL(string: "fake.com")!
            )
        )
    
    static let token = "meowmeow1234"
    static let id = "meow1234"
    static let username = "meowface"
    static let password = "Test1234"
    
    static let keychainService = "PocketBase.AuthTests"
    
    static let authResponse = AuthResponse(
        token: token,
        record: tester
    )
    
    static let tester = Tester(
        id: id,
        username: username
    )
    
    @Test(
        "Login",
        arguments: zip(
            [
                Self.identityLogin,
                Self.oauthLogin,
            ],
            [
                Self.authResponse,
                Self.authResponse
            ]
        )
    )
    func login(
        method: RecordCollection<Tester>.AuthMethod,
        response: AuthResponse<Tester>
    ) async throws {
        let mockSession = MockNetworkSession(
            data: try PocketBase.encoder.encode(response, configuration: .cache),
            response: HTTPURLResponse(),
            shouldThrow: false,
            stream: nil
        )
        let pocketbase = PocketBase(
            url: .localhost,
            session: mockSession,
            authStore: AuthStore(
                keychain: MockKeychain(
                    service: Self.keychainService
                )
            )
        )
        let collection = pocketbase.collection(Tester.self)
        switch method {
        case .identity:
            let tester = try await collection.login(with: method)
            #expect(response.record.id == tester.id)
            #expect(response.record.username == tester.username)
            
            // Test cache
            #expect(pocketbase.authStore.token == response.token)
            let cachedTester: Tester? = try pocketbase.authStore.record()
            #expect(cachedTester?.id == response.record.id)
        case .oauth:
            await #expect(
                throws: PocketBaseError.notImplemented,
                performing: {
                    try await collection.login(with: method)
                }
            )
        }
    }
    
    @Test
    func logout() async throws {
        // MARK: GIVEN a logged in user
        let response = Self.authResponse
        let mockSession = MockNetworkSession(
            data: try PocketBase.encoder.encode(
                response,
                configuration: .cache
            ),
            response: HTTPURLResponse(),
            shouldThrow: false,
            stream: nil
        )
        let pocketbase = PocketBase(
            url: .localhost,
            session: mockSession
        )
        let collection = pocketbase.collection(Tester.self)
        
        let tester = try await collection.login(with: Self.identityLogin)
        #expect(response.record.id == tester.id)
        #expect(response.record.username == tester.username)
        
        // MARK: THEN Cache should have values
        #expect(pocketbase.authStore.token == response.token)
        #expect((try pocketbase.authStore.record() as Tester?)?.id == response.record.id)
        
        let expectedRequest = try {
            var request = URLRequest(
                url: URL(
                    string: "http://localhost:8090/api/collections/testers/auth-with-password?expand=rawrs"
                )!
            )
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(
                AuthWithPasswordBody(
                    identity: Self.username,
                    password: Self.password
                ),
                configuration: .cache
            )
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return request
        }()
        #expect(mockSession.lastRequest == expectedRequest)
        
        // MARK: WHEN Logged out
        await collection.logout()
        
        // MARK: THEN Cache should NOT have values
        #expect(pocketbase.authStore.token == nil)
        #expect(try pocketbase.authStore.record() as Tester? == nil)
    }
}
