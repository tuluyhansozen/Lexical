import Foundation

#if canImport(AuthenticationServices) && canImport(UIKit)
import AuthenticationServices
import UIKit
#endif

public struct AuthenticatedUser: Sendable {
    public let userId: String
    public let displayName: String?
    public let emailRelay: String?
    public let identityToken: String?
    public let authorizationCode: String?

    public init(
        userId: String,
        displayName: String?,
        emailRelay: String?,
        identityToken: String?,
        authorizationCode: String?
    ) {
        self.userId = userId
        self.displayName = displayName
        self.emailRelay = emailRelay
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
    }
}

public enum AuthenticationServiceError: Error {
    case notSupported
    case missingPresentationAnchor
    case invalidCredential
    case canceled
    case signInAlreadyInProgress
}

#if canImport(AuthenticationServices) && canImport(UIKit)

@MainActor
public final class AuthenticationService: NSObject {
    public typealias PresentationAnchorProvider = @MainActor () -> ASPresentationAnchor?

    private let presentationAnchorProvider: PresentationAnchorProvider
    private var continuation: CheckedContinuation<AuthenticatedUser, Error>?

    public init(
        presentationAnchorProvider: PresentationAnchorProvider? = nil
    ) {
        self.presentationAnchorProvider = presentationAnchorProvider ?? {
            Self.defaultPresentationAnchor()
        }
        super.init()
    }

    public func signInWithApple() async throws -> AuthenticatedUser {
        guard continuation == nil else {
            throw AuthenticationServiceError.signInAlreadyInProgress
        }

        guard presentationAnchorProvider() != nil else {
            throw AuthenticationServiceError.missingPresentationAnchor
        }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private func resolve(_ result: Result<AuthenticatedUser, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    private static func defaultPresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            resolve(.failure(AuthenticationServiceError.invalidCredential))
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let displayName = credential.fullName
            .flatMap { formatter.string(from: $0) }
            .flatMap { $0.nilIfEmpty }

        let identityToken = credential.identityToken.flatMap {
            String(data: $0, encoding: .utf8)
        }
        let authorizationCode = credential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }

        let user = AuthenticatedUser(
            userId: credential.user,
            displayName: displayName,
            emailRelay: credential.email,
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )
        resolve(.success(user))
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            resolve(.failure(AuthenticationServiceError.canceled))
            return
        }
        resolve(.failure(error))
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchorProvider()
            ?? Self.defaultPresentationAnchor()
            ?? ASPresentationAnchor(frame: .zero)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#else

@MainActor
public final class AuthenticationService {
    public init() {}

    public func signInWithApple() async throws -> AuthenticatedUser {
        throw AuthenticationServiceError.notSupported
    }
}

#endif
