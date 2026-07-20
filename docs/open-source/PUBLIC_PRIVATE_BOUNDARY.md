# Public/private boundary

| Public | Private / excluded |
| --- | --- |
| Apache-2.0 source, tests, scripts, first-party docs, generated source manifest/SBOM | Signing private keys, notarization/App Store credentials, private endpoints, account tokens |
| Sanitized published Git history using the approved maintainer noreply email and GitHub service noreply identities | Workstation paths, personal email addresses, internal agent plans/reflections |
| RSI Tech website, `info@rsitech.ai`, governance, security policy, license and NOTICE | Private report contents, OCR/clipboard payloads, screenshots and user data |
| Neutral local community build identity and official direct-download metadata | Any claim of notarization, sandbox, or App Store acceptance without exact evidence |

No secret value should ever be added to an inventory, generated artifact, issue, log, or commit.
