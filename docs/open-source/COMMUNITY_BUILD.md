# Community build

The source-build path is the unofficial community distribution lane documented in `../community-build/README.md`. Its default identity is:

- display name: `SnapAction Community`
- bundle identifier: `org.example.snapaction.community`
- build system: Swift Package Manager
- platform: macOS 26 or later

`Config/Community.example.env` contains public example values. `script/build_and_run.sh --print-config` validates configuration without building or launching the app. A community build is not signed, notarized, sandboxed, or eligible for App Store upload merely because it compiles.
