# Suggested Prompts for SSOJet OIDC — PHP (Vanilla)

## Full Implementation

> "Add 'Sign in with SSO' to my vanilla PHP application using SSOJet.
>
> Follow `skills/authentication/oidc-hosted-page-php/SKILL.md` exactly.
>
> Requirements:
> 1. Install `jumbojett/openid-connect-php` via Composer.
> 2. Create a `config.php` with Issuer URL, Client ID, Client Secret, and Redirect URI.
> 3. Add an SSO toggle to my `login.php` page.
> 4. Create `auth.php` that detects SSO mode and initiates the OIDC redirect.
> 5. Create `callback.php` that handles the OIDC response, extracts user info, and stores it in the PHP session.
>
> My SSOJet config:
> - Issuer URL: `https://auth.ssojet.com`
> - Client ID: `<my_client_id>`
> - Redirect URI: `http://localhost:8000/callback.php`"
