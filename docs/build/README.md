# Build SnapAction from source

SnapAction is a SwiftPM macOS 26 application with two products:

- `SnapActionCore`, the testable library.
- `SnapAction`, the executable staged inside the local app bundle.

## Requirements

- macOS 26 or newer.
- A Swift 6.2 toolchain compatible with the package declaration.
- Xcode command-line development tools for the Apple frameworks used by the app.
- Python 3; publication tooling uses only the standard library.

## Compile and test

```bash
swift build -c release -Xswiftc -warnings-as-errors
swift test
```

## Stage and verify a community app bundle

```bash
bash script/test_build_configuration.sh
bash script/test_bundle_metadata.sh
bash script/build_and_run.sh --verify
```

The staging script validates identity and source-metadata values before generating `Info.plist`. `--verify` compiles, stages, launches, checks the exact executable process, runs tests, and confirms the app remains alive. This proves a local development bundle can launch; it does not prove distribution signing, hardened runtime, notarization, App Sandbox compatibility, or Mac App Store acceptance.

The default output is explicitly unofficial. See [the community-build guide](../community-build/README.md) before overriding its identity.
