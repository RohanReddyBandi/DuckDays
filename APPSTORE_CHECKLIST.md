# App Store Submission Checklist

## Prereqs
- [ ] Apple Developer account active ($99/yr)
- [ ] Xcode installed
- [ ] App name checked for App Store collisions

## Project config
- [ ] App name set in app.json (or Xcode project)
- [ ] Bundle identifier set (brand.appname format) — final, can't change later
- [ ] supportsTablet: false (unless committing to iPad support permanently)
- [ ] Encryption exemption flag set (usesNonExemptEncryption: false)
- [ ] Version set to 1.0.0
- [ ] App icon ready (1024x1024, all sizes)

## Build
- [ ] `npx expo prebuild --platform ios --clean`
- [ ] Open ios/ folder in Xcode
- [ ] Sign in to Apple Developer account in Xcode
- [ ] Signing & Capabilities: automatic signing + correct team (all targets incl. widgets)
- [ ] Select "Any iOS Device (arm64)" target
- [ ] Product > Archive
- [ ] Distribute App > App Store Connect > register bundle ID

## TestFlight
- [ ] Install TestFlight on phone
- [ ] Wait for build to process in App Store Connect
- [ ] Create internal testing group (auto-distribution on)
- [ ] Add self as tester, accept invite, install, verify build works

## Store listing
- [ ] Screenshots (real device, all required sizes)
- [ ] Promotional text
- [ ] Description
- [ ] Keywords
- [ ] Support URL
- [ ] Privacy policy URL
- [ ] Copyright line
- [ ] Select build to submit
- [ ] App Review info (login creds if auth required)
- [ ] Auto-release vs manual release choice

## App info / privacy / pricing
- [ ] Subtitle + category (up to 2)
- [ ] Content rights declaration
- [ ] Age rating questionnaire
- [ ] App Privacy data collection declaration
- [ ] Price tier or free
- [ ] Country availability

## Submit
- [ ] Add for Review
- [ ] Resolve any flagged missing fields
