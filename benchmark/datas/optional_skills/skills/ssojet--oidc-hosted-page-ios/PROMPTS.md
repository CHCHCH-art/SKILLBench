# Suggested Prompts for SSOJet OIDC — iOS / Swift

## Full Implementation

> "Add 'Sign in with SSO' to my native iOS (Swift/UIKit) application using SSOJet.
>
> Follow `skills/authentication/oidc-hosted-page-ios/SKILL.md` exactly.
>
> Requirements:
> 1. Add `AppAuth-iOS` via Swift Package Manager.
> 2. Configure the custom URL scheme in `Info.plist`.
> 3. Create an `AuthConfig` struct and an `AuthManager` singleton.
> 4. Add an SSO toggle button to my login view controller.
> 5. Use AppAuth to launch the authorization request with PKCE and `login_hint`.
> 6. Handle the redirect in `AppDelegate` / `SceneDelegate` and navigate to the dashboard on success.
>
> My SSOJet config:
> - Issuer URL: `https://auth.ssojet.com`
> - Client ID: `<my_client_id>`
> - Redirect URI: `com.example.myapp://auth/callback`"

## SwiftUI Variant

> "I'm using SwiftUI instead of UIKit. Adapt the SSO flow from `skills/authentication/oidc-hosted-page-ios/SKILL.md`
> to use `ASWebAuthenticationSession` wrapped in a SwiftUI coordinator."
