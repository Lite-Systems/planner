# macOS CI signing

The GitHub macOS workflow produces a **certificate-free test DMG**. It uses
ad-hoc signing (`CODE_SIGN_IDENTITY = -`), not an Apple development or
distribution certificate. No private key is required on the hosted runner.

## Why the workflow failed

Runner and PlannerWidget share the Apple team and signing identity in
`macos/Runner/Configs/AppInfo.xcconfig`. The hosted runner has no matching
certificate/private key, so both targets failed with `No signing certificate
"Mac Development" found` before packaging.

The workflow now sets `XCODE_XCCONFIG_FILE` to
`macos/Runner/Configs/CI.xcconfig` during its build step. Xcode applies these
overrides to the app, widget and embedded code. Signing remains enabled so
Apple Silicon binaries receive ad-hoc signatures and the existing deep/strict
signature validation still runs. Normal project signing settings are unchanged.

After building, `ruby macos/Tests/check_ci_signing.rb` checks the effective
Xcode settings for both Runner and PlannerWidget under that same environment.
It fails if either target reverts to certificate-based signing or disables
signing entirely. The workflow also checks both CPU architectures, validates
the DMG and uploads the artifact as before.

## Limitations

- This CI DMG is not notarized and is not an App Store/distribution-signed build.
- Ad-hoc signing does not authorize the widget's App Group. Widget sharing
  requires the app and extension to be signed by the same authorized Apple team.
- Do not include `CI.xcconfig` from local Debug/Profile/Release configurations.
  Use the normal `flutter build macos --release` command on a Mac with the
  configured Apple signing identity for widget-capable builds.
- A future notarized or widget-capable CI release needs a separate signing
  setup using authorized Apple certificates/private keys and any required
  provisioning/notarization credentials. This change does not export or upload
  certificates, change the local keychain, or weaken widget privacy checks.

Flutter's [macOS release guide](https://docs.flutter.dev/deployment/macos)
describes Apple-signed distribution and certificate setup.
