# Distribution & Signing

## Release flow

Pushing a tag `v*` that matches `MARKETING_VERSION` in `project.yml` triggers
`.github/workflows/release.yml`:

1. Re-run tests, the coverage gate, and a build (never ship unverified code)
2. Build Release and sign — **Developer ID if secrets are configured, ad-hoc
   otherwise** (with a loud notice)
3. Package a DMG (`scripts/package_dmg.sh`, plain `hdiutil` — no dependencies)
4. Notarize + staple — again secret-gated, skipped with a notice otherwise
5. Attest build provenance (`actions/attest-build-provenance`)
6. Create the GitHub Release with generated notes and the DMG attached

Bump `MARKETING_VERSION` first; the workflow fails loudly if the tag and the
project version disagree.

## Required secrets for trusted distribution

All optional — without them you still get an ad-hoc-signed DMG.

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_CERT_P12` | Base64-encoded "Developer ID Application" certificate + private key (.p12) |
| `DEVELOPER_ID_CERT_PASSWORD` | Password protecting that .p12 |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_TEAM_ID` | 10-character team identifier |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` (create at appleid.apple.com) |

Signing and notarization require a paid
[Apple Developer Program](https://developer.apple.com/programs/) membership
($99/year).

The three `APPLE_*` secrets only take effect when the `DEVELOPER_ID_*` pair
is also configured — Apple's notary service always rejects ad-hoc-signed
submissions, so the workflow skips notarization (with a warning) rather than
submit one.

## The unsigned-build caveat (be honest with your users)

On Apple Silicon everything is at least ad-hoc signed, but a **downloaded**
app that is not Developer-ID-signed *and* notarized is blocked by Gatekeeper —
and since macOS 15 the Control-click → Open bypass is gone. Users of unsigned
builds must clear quarantine manually:

```bash
xattr -dr com.apple.quarantine /Applications/Spyglass.app
```

Document this in your release notes, or better, configure the secrets above.

## Future steps (deliberately out of template scope)

- **Homebrew cask**: as of Homebrew 5.0 (2026), unsigned/un-notarized casks
  are removed from homebrew/cask — notarization is a hard prerequisite.
- **Sparkle**: in-app updates for direct distribution; add it only when users
  ask, and sign your appcast (see
  [Sparkle's documentation](https://sparkle-project.org/documentation/)).
- **Mac App Store**: a different signing/provisioning pipeline entirely; this
  template targets direct distribution via GitHub Releases.
