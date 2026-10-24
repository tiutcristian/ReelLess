# ReelLess

DM-only Instagram for iPhone. A SwiftUI shell around Instagram's own web DM client (`WKWebView`), restricted to `/direct/*`.

## Run

```bash
brew install xcodegen
xcodegen generate
open ReelLess.xcodeproj
```

In Xcode: select the ReelLess target → Signing & Capabilities → pick your Team, then Run on your iPhone
(Developer Mode must be on: Settings → Privacy & Security).

Core logic check (no Xcode needed): see `Packages/ReelLessCore`.

## Layout

- `Packages/ReelLessCore` – pure Swift: `RoutePolicy`, `RulePack`, injected JS/CSS (`Shield`). Fix breakage in `Resources/rule-pack.default.json`.
- `App/` – SwiftUI app, web container, one-item viewer, settings (three-finger tap).
