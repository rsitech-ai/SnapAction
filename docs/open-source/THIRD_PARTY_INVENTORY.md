# Third-party inventory

`Package.swift` declares zero external Swift package dependencies and the repository has no `Package.resolved`. The generated manifest records an external Swift package count of zero.

The source imports Apple platform modules including AppKit, CoreGraphics, EventKit, Foundation, FoundationModels, Observation, OSLog, ScreenCaptureKit, SwiftUI, and Vision. These are system/SDK frameworks provided by Apple. They are identified in the SBOM as `provided-by-platform` and `redistributed=false`; they are not counted as redistributed third-party packages.

The `swift-tools-version: 6.2` declaration is a source-level SwiftPM manifest compatibility requirement. It is not evidence of the installed Swift compiler or toolchain and is not an application dependency. This inventory does not replace a formal license review if dependencies or bundled assets are added later.
