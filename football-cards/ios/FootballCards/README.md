# FootballCards iOS App

This folder contains the standalone SwiftUI iOS app for the football trading cards product.

The app now has a standalone Xcode project at `football-cards/ios/FootballCards/FootballCards.xcodeproj`.

Current app capabilities:

- Email/password login against `/api/football/auth/login`
- Registration against `/api/football/auth/register`
- Apple Sign In against `/api/football/auth/apple`
- First-login onboarding with supported club selection and starter-pack allocation
- Dashboard showing profile, collection summary, and starter-pack cards
- Collection tab with filters for slot, club, and player search
- Starter-pack reveal flow after onboarding allocation
- Admin tab with sync trigger and sync-status monitoring for admin users
- Settings tab for switching football API hosts and optional admin token override

For the admin sync-status debug section, the app reads:

- `football_api_base_url` from `UserDefaults` (defaults to `https://www.sharequest.co.uk/api/football`)
- `football_admin_token` from `UserDefaults` for `Authorization: Bearer <token>` override

If `football_admin_token` is not set, the app falls back to the signed-in user's JWT for admin football endpoints.

Auth now runs entirely through the football namespace. The standalone app no longer depends on `/api/mobile/auth/*`.