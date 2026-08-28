# Nextcloud SMB

A hardened, reproducible Nextcloud Apache image with the PHP `smbclient`
extension and Samba client installed for external SMB storage.

## Run

```console
docker run --name nextcloud-smb --publish 8080:8080 \
  --volume nextcloud:/var/www/html \
  ghcr.io/arumes31/nextcloud-smb:production-smb
```

The image listens on port 8080 and runs as `www-data` (UID/GID 33). When using
a bind mount, make the target writable by UID 33. The standard Nextcloud image
environment variables and volumes remain supported.

## Security and maintenance

- The Nextcloud base, PECL extension release, Samba packages, actions, and scanners are
  version or digest pinned.
- CI verifies the extension, CLI, non-root runtime, health endpoint, and bounded
  failure behavior before scanning the resulting image for high/critical issues.
- The daily publisher emits amd64/arm64 images, SBOM and provenance attestations.
- Dependabot proposes Docker and GitHub Actions updates. Review base-image bumps
  promptly because a digest pin intentionally prevents unreviewed drift.

See [SECURITY.md](SECURITY.md) to report vulnerabilities.

## License

MIT
