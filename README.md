# Nextcloud SMB

A hardened Nextcloud Apache image with the PHP `smbclient`
extension and Samba client installed for external SMB storage.

Both build stages use the moving `nextcloud:production` tag. CI resolves it to
one digest for both stages and the upstream vulnerability comparison. CI and the
daily publisher pull the current base image on every build.

## Run

```console
docker run --pull always --name nextcloud-smb --publish 8080:8080 \
  --volume nextcloud:/var/www/html \
  ghcr.io/arumes31/nextcloud-smb:production-smb
```

The image listens on port 8080 and runs as `www-data` (UID/GID 33). When using
a bind mount, make the target writable by UID 33. The standard Nextcloud image
environment variables and volumes remain supported.

When `REDIS_HOST` is set, the upstream entrypoint configures Redis sessions in a
pre-created `redis-session.ini` owned by UID 33 with mode `0600`. The PHP
configuration directory remains root-owned; only this session file is writable
by the runtime user.

## Build

```console
docker build --pull --tag nextcloud-smb:local .
```

Use `--pull` when rebuilding locally to pick up the current `nextcloud:production`
image instead of reusing a cached base image.

## Security and maintenance

- The default Nextcloud base tracks the moving `nextcloud:production` tag.
- The PECL extension release, Debian packages, actions, and scanners remain
  version or digest pinned.
- CI verifies the extension, CLI, non-root runtime, startup with and without
  Redis session configuration, health endpoint, and bounded failure behavior
  before scanning the resulting image for high/critical issues.
- CVEs inherited from the exact upstream image are reported in the CI summary
  and allowed, preserving Nextcloud's signed core. Fixable high/critical CVEs
  added by this image still fail CI. Matching includes the package version and
  library location; high/critical secret findings and scanner errors also fail.
- The daily publisher emits amd64/arm64 images, SBOM and provenance attestations.
- Publishing runs on every push to `main`, daily, and manually through the
  `Publish image` workflow. To publish the current `main` manually:

  ```console
  gh workflow run publish.yml --repo arumes31/nextcloud-smb --ref main
  ```

- A separate keepalive job on scheduled and manual publishing runs re-enables
  both scheduled workflows through the GitHub API, even if the image build fails.
  This is a workaround for GitHub's inactivity timeout; if publishing is already
  disabled, enable the workflow manually first.
- Dependabot proposes Docker and GitHub Actions updates. Keep the Nextcloud base
  on `production`; review updates to the remaining pinned dependencies promptly.

See [SECURITY.md](SECURITY.md) to report vulnerabilities.

## License

MIT
