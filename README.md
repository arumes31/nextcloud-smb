# Nextcloud SMB

A hardened Nextcloud Apache image with the PHP `smbclient`
extension and Samba client installed for external SMB storage.

Both build stages use the same upstream tag, defaulting to `nextcloud:production`.
CI and the publisher also build a separate Nextcloud 33 variant and pull the
current base image on every build.

| GHCR image tag | Upstream base | Updates |
| --- | --- | --- |
| `production-smb` | `nextcloud:production` | Follows the production channel |
| `33-smb` | `nextcloud:33-apache` | Follows 33.x releases |

## Run

```console
docker run --pull always --name nextcloud-smb --publish 8080:8080 \
  --volume nextcloud:/var/www/html \
  ghcr.io/arumes31/nextcloud-smb:production-smb
```

For Nextcloud 33, use `ghcr.io/arumes31/nextcloud-smb:33-smb` instead.
The 33 tag follows upstream patch updates rather than staying on `33.0.9`.
Do not use it to downgrade an existing installation from a newer major version.

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

To build the Nextcloud 33 variant locally:

```console
docker build --pull --build-arg NEXTCLOUD_TAG=33-apache --tag nextcloud-smb:33-local .
```

## Security and maintenance

- The default base tracks `nextcloud:production`; the Nextcloud 33 variant tracks
  `nextcloud:33-apache`. Neither is pinned to a patch release or digest.
- The PECL extension release, Debian packages, actions, and scanners remain
  version or digest pinned.
- CI tests both variants, including the Nextcloud 33 major version, and verifies
  the extension, CLI, non-root runtime, startup with and without
  Redis session configuration, health endpoint, and bounded failure behavior
  before scanning the resulting image for high/critical issues.
- The publisher emits amd64/arm64 images, SBOM and provenance attestations for
  both variants. Commit tags use `sha-<commit>` for production and
  `33-sha-<commit>` for Nextcloud 33.
- Publishing runs on every push to `main`, daily, and manually through the
  `Publish image` workflow. To publish the current `main` manually:

  ```console
  gh workflow run publish.yml --repo arumes31/nextcloud-smb --ref main
  ```

- A separate keepalive job on scheduled and manual publishing runs re-enables
  both scheduled workflows through the GitHub API, even if the image build fails.
  This is a workaround for GitHub's inactivity timeout; if publishing is already
  disabled, enable the workflow manually first.
- Dependabot proposes Docker and GitHub Actions updates. Keep the default base
  on `production` and the 33 variant on `33-apache`; review updates to the
  remaining pinned dependencies promptly.

See [SECURITY.md](SECURITY.md) to report vulnerabilities.

## License

MIT
