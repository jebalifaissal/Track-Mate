# Track-Mate — Client / Driver production branch

This branch replaces the old role-switching demo entry point with two account roles:
- Client: register/login, create a delivery request with pickup GPS and destination coordinates, view saved orders and request the driver's latest location.
- Driver: register/login, see available and assigned deliveries, accept one, update delivery milestones and share foreground GPS while the app remains open.

## Backend

Cloudflare Worker source: `trackmate/src/index.ts`  
D1 database: `trackmate`  
D1 migrations: `trackmate/migrations`

The API uses PBKDF2 password hashes, random bearer sessions stored as SHA-256 token hashes, parameterized SQL, role checks and D1 persistence.

### Deploy Worker (PowerShell)

```powershell
cd .\trackmate
npm.cmd install
npx.cmd wrangler d1 migrations list trackmate --remote
npx.cmd wrangler d1 migrations apply trackmate --remote
npx.cmd wrangler deploy
```

Copy the deployed Worker URL printed by Wrangler. Do not guess the subdomain.

## Flutter

From the Flutter project root:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run --dart-define=TRACKMATE_API_URL=https://YOUR-DEPLOYED-WORKER-URL
```

Replace the URL with the exact Worker URL printed after deploy. The default URL in the source is intentionally a placeholder.

## Important limitations before public commercial launch

- GPS sharing currently runs in the foreground while the driver app is open. Android background execution / foreground-service notification and iOS background location permissions still need a dedicated implementation and physical-device validation.
- Client tracking currently retrieves the latest saved driver coordinates on request; a continuously refreshing map / push updates are not yet implemented.
- Destination latitude and longitude are entered by the client. Add a Places/geocoding provider and map pin picker before broad release.
- Payment gateway, identity/phone verification, operational support tooling, rate limiting, abuse controls, privacy/retention policy and end-to-end tests are not included yet. No card data is stored by this API.
- Run the migrations against a staging D1 database first if the target database does not already have the original schema. The existing production D1 database already has migration 0001 recorded; this branch restores that baseline migration file for reproducibility.
- Do not commit `.dev.vars`, API secrets, or local Wrangler state.

This is a functional first client/driver backend slice, not a claim that every commercial launch requirement is complete.
