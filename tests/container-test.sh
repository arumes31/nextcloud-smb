#!/usr/bin/env bash
set -euo pipefail

image="${1:-nextcloud-smb:test}"

php_info="$(docker run --rm "${image}" php --ri smbclient)"
grep -qi "smbclient support => enabled" <<<"${php_info}"

docker run --rm "${image}" smbclient --version | grep -q '^Version '

configured_user="$(docker image inspect "${image}" --format '{{.Config.User}}')"
test "${configured_user}" = "33:33"

configured_port="$(docker image inspect "${image}" --format '{{json .Config.ExposedPorts}}')"
grep -q '8080/tcp' <<<"${configured_port}"

# An unreachable SMB endpoint must fail promptly instead of hanging a worker.
# The single-quoted expression is PHP code evaluated in-container.
# shellcheck disable=SC2016
timeout 10s docker run --rm "${image}" php -r '
    $state = smbclient_state_new();
    if (!smbclient_state_init($state, "missing", "nobody", "invalid")) {
        exit(2);
    }
    $directory = @smbclient_opendir($state, "smb://127.0.0.1/missing");
    exit($directory === false ? 0 : 1);
'

container_id="$(docker run --detach --rm --publish 127.0.0.1::8080 "${image}")"
trap 'docker stop "${container_id}" >/dev/null 2>&1 || true' EXIT

host_port="$(docker port "${container_id}" 8080/tcp | awk -F: 'NR == 1 {print $NF}')"
for _ in $(seq 1 45); do
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_id}")"
    if [[ "${health}" == "healthy" ]]; then
        break
    fi
    if [[ "$(docker inspect --format '{{.State.Running}}' "${container_id}")" != "true" ]]; then
        docker logs "${container_id}"
        exit 1
    fi
    sleep 2
done

test "$(docker inspect --format '{{.State.Health.Status}}' "${container_id}")" = "healthy"
curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${host_port}/status.php" >/dev/null
