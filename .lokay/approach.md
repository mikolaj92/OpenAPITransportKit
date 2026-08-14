# Approach plan

<!-- lokay-approach source=deterministic repo=mikolaj92/OpenAPITransportKit issue=9 -->

Repository: `mikolaj92/OpenAPITransportKit`  
Issue: #9 — README każe package swift-openapi-transport-kit przy URL OpenAPITransportKit.git

## Goal

Make README/DocC install snippets copy-pasteable for the published git URL.
SwiftPM git identity is the URL last path component (`OpenAPITransportKit`),
not `Package.swift` `name` (`swift-openapi-transport-kit`). Also stop telling
releasers to verify CI that this repo does not ship.

## Files likely touched

- `README.md`
- `Package.swift` (comment only; keep path-dep name so IntegrationTests still resolve)
- `Sources/OpenAPITransportKit/Documentation.docc/GettingStarted.md`
- `Sources/OpenAPITransportKit/Documentation.docc/MultiplatformCompatibility.md`
- `RELEASE.md`

## Test plan

- `swift package dump-package` to confirm the manifest still parses
- `swift test` if practical
- Do not rename `Package.swift` `name` (would break path-dep IntegrationTests,
  whose Package.swift is out of localize scope)

## Non-goals

- Renaming the GitHub repository
- Re-adding GitHub Actions workflows
- Changing IntegrationTests path-dependency identity

## Notes

- Trust intentional issue; this plan is evidence for later review, not a human gate.
- Coding agent may refine details but should stay on the stated goal and non-goals.
- Collector boundary: if implementation introduces unbounded collection, ship only a bounded collector patch that starts durably in the background after merge. The coding agent and mill must not populate data or wait for collection to finish.
