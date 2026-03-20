# Releasing

This repository currently publishes public artifacts through GitHub releases only.

## Tag format

Release tags should match the versions pinned in `Makefile`:

```bash
v<HAPROXY_VERSION>-aws-lc-<AWS_LC_VERSION>
```

Example:

```bash
v3.2.15-aws-lc-1.71.0
```

The release workflow validates that the pushed tag matches the versions currently defined in `Makefile`.

## Local dry run

Build the same asset bundle used by the GitHub Release workflow:

```bash
make docker-build
make release-bundle
```

That produces:

- binary RPMs
- source RPMs
- `SHA256SUMS`
- `release-notes.md`

under `release-artifacts/`.

## Publishing a draft GitHub Release

1. Update `HAPROXY_VERSION` and `AWS_LC_VERSION` in `Makefile` if needed.
2. Run a local dry run with `make docker-build` and `make release-bundle`.
3. Load the release metadata from `Makefile`:

```bash
eval "$(make --silent print-release-env)"
```

4. Create and push an annotated tag:

```bash
git tag -a "${RELEASE_TAG}" -m "${RELEASE_TITLE}"
git push origin "${RELEASE_TAG}"
```

5. GitHub Actions will build the RPM/SRPM assets, attach `SHA256SUMS`, and create or update a draft GitHub Release for that tag.
6. Review the draft release in GitHub, then publish it manually when satisfied.
