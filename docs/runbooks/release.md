# Release runbook

This is the order the owner follows. Nothing here is done by CI except the tag run.

## Before the first tag

1. **Branch protection on `main`.** Require the `test` matrix, `coverage`, `shared-check` and
   `release-dry-run`. Require a pull request and a linear history. Do not allow force pushes.
2. **The `production` environment.** Create it under Settings, Environments. Add a deployment tag
   rule that allows only `v*`. Add required reviewers if the owner wants a manual approval.
3. **Secrets.** None are needed for this repository. The release uses the workflow's
   `GITHUB_TOKEN` and the `attestations: write` and `id-token: write` permissions.
4. **Registry setup.** None. Zig has no registry, so there is no trusted publisher and no pending
   publisher to create.
5. **Dependabot.** Enable Dependabot alerts and automated security fixes in Settings, Code security.
   Dependabot version updates read `.github/dependabot.yml`; only the GitHub Actions ecosystem is
   configured because Zig has no package manager.
6. **Environment label for the published check.** Create the `published-check` label used by
   `verify-published.yml` when a scheduled run fails.

## The version bump

1. Change `.version` in `build.zig.zon` and the status line in `README.md`.
2. Move the `Unreleased` entries in `CHANGELOG.md` under `## [<version>] - YYYY-MM-DD`.
3. Run `scripts/ci.sh` and `python tools/release_check.py --tag v<version>`.
4. Merge the bump pull request.

## The tag

1. `git tag v<version>` on the merge commit and push the tag.
2. `release.yml` checks that the tagged commit is on `main`, that the manifest, tag and changelog
   agree, runs every gate, creates the source archive, writes `SHA256SUMS`, computes the Zig hash
   with `zig fetch`, attests the archive, and creates the GitHub release.
3. The release job calls `verify-published.yml`, which fetches the tag with `zig fetch` on Linux,
   macOS and Windows and runs the sample.
4. Check the release body: the `zig fetch --save` command, the `build.zig.zon` snippet with the
   recorded hash, and the SHA-256 must all be present.

## After the first release

1. The hub branch for this port (`feat/nepdate-zig`) is not merged before the release. Merge it at
   the 1.0.0 release with the hub line move, and add the `sdks` entry in `spec/versions.json` in the
   same release pull request. This port starts with no entry, which hub ADR-0008 allows.
2. Add the release to the site's port list only when the line moves.
3. Schedule the quiet benchmark rerun and replace the preliminary table.
