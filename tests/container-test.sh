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

container_id=''
cleanup() {
    if [[ -n "${container_id}" ]]; then
        docker rm --force --volumes "${container_id}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

for session_handler in default redis; do
    echo "Testing startup with ${session_handler} sessions"
    environment=()
    if [[ "${session_handler}" == redis ]]; then
        environment=(--env REDIS_HOST=redis --env REDIS_HOST_PORT=6380)
    fi
    container_id="$(docker run --detach --publish 127.0.0.1::8080 "${environment[@]}" "${image}")"
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

    if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${container_id}")" != healthy ]]; then
        docker logs "${container_id}"
        exit 1
    fi
    host_port="$(docker port "${container_id}" 8080/tcp | awk -F: 'NR == 1 {print $NF}')"
    curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:${host_port}/status.php" >/dev/null

    if [[ "${session_handler}" == redis ]]; then
        docker exec "${container_id}" php -r '
            exit(
                ini_get("session.save_handler") === "redis"
                && ini_get("session.save_path") === "tcp://redis:6380"
                && ini_get("redis.session.locking_enabled") === "1"
                && !is_writable("/usr/local/etc/php/conf.d")
                && (fileperms("/usr/local/etc/php/conf.d/redis-session.ini") & 0777) === 0600
                ? 0 : 1
            );
        '
    fi

    cleanup
    container_id=''
done
