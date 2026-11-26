# Janhavi Panwar App (Flutter + Go)

## Backend (Go 1.22+, no extra libraries)
    cd backend
    ADMIN_KEY=meraSecret123 go run .        # http://localhost:8080
OTP abhi console me print hota hai (testing). Data `data.json` me save hota hai.

## Admin APIs (header `X-Admin-Key: meraSecret123`)
- GET  /api/admin/reviews , POST /api/admin/reviews/{id}/approve
- POST /api/admin/courses (course/offer: Price, MRP, OfferLabel, OfferEnds)
- POST /api/admin/combos , POST /api/admin/quiz/{courseId}
- GET  /api/admin/students
- PUT  /api/admin/settings  {"smtp_host","smtp_port","smtp_user","smtp_pass","wa_url","wa_token"}  <- API keys yahin
- POST /api/admin/broadcast {"channel":"email|whatsapp","subject":"..","message":"..","UserIDs":[]}  (empty = sab students)

## App
    cd app && flutter create . && flutter pub get && flutter run
`lib/main.dart` me `base` URL badlo. Google login ke liye Firebase/Google Cloud me Android SHA-1 add karna hoga.

## iPhone / iOS
GitHub -> Actions -> "Build app" -> Run workflow (enter your Render URL).
- `janhavi-app-ios-unsigned` artifact = unsigned .ipa (needs signing before it installs on iPhone)
- Web version is published on GitHub Pages: `https://<username>.github.io/<repo>/` (open in iPhone Safari -> Share -> Add to Home Screen)
- Settings -> Pages -> Source must be set to "GitHub Actions" (one time).
- Google login is hidden on iOS until the iOS client ID is configured.
