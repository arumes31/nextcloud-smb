# Nextcloud image

- Always use `nextcloud:production` for the Nextcloud Docker image.
- Track the current `production` tag rather than pinning a version or using `latest`.
- Pull the current image when deploying or rebuilding so the cached image does not keep the deployment on an older release.
