# SnapAction Community builds

The build script produces an **unofficial community build** by default. Its visible name is `SnapAction Community` and its bundle identifier is `org.example.snapaction.community`; these defaults do not impersonate an owner-published build.

```bash
./script/build_and_run.sh --print-config
./script/build_and_run.sh --verify
```

The staged bundle is written to `dist/SnapAction Community.app`. It is a local development artifact, not a distribution-signed, notarized, or Mac App Store package.

## Use an identity you control

Copy `Config/Community.example.env` to a file outside version control, edit it, then export its values before invoking the script:

```bash
set -a
source /path/to/MyCommunity.env
set +a
./script/build_and_run.sh --verify
```

Supported variables:

- `SNAP_ACTION_APP_NAME`: 1–64 letters, numbers, spaces, dots, underscores, or hyphens.
- `SNAP_ACTION_BUNDLE_ID`: reverse-DNS identifier with at least two components.
- `SNAP_ACTION_VERSION`: one to three dot-separated integer components.
- `SNAP_ACTION_BUILD`: positive integer.
- `SNAP_ACTION_SOURCE_URL`: optional credential-free HTTPS source URL.
- `SNAP_ACTION_SOURCE_REVISION`: exact 40-character Git revision; the checked-out revision is used when omitted.

Invalid values fail before an app is stopped, built, or staged. Configuration changes identity and metadata only; it does not provide signing or release authority. Official names, identifiers, credentials, accounts, and release permissions remain owner-controlled and outside Git.
