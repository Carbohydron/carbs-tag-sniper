# Releasing

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) in
`.github/workflows/release.yml`. Pushing a tag starting with `v` builds
`Carbs-Tag-Sniper-<tag>-forever.zip`, stamps the tag into the `.toc` version, and uploads it to
CurseForge, Wago Addons and a GitHub release. A tag containing `alpha` or `beta` is uploaded
as an alpha or beta.

1. Add the new version's notes to `CHANGELOG.md` and commit.
2. `git tag -a v1.2.3 -m "v1.2.3"` then `git push origin v1.2.3`.

Uploads need the `CF_API_KEY` and `WAGO_API_TOKEN` repository secrets and the
`X-Curse-Project-ID` and `X-Wago-ID` lines in the `.toc`. A site without them is skipped.
