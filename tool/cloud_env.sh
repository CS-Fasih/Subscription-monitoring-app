#!/usr/bin/env bash
# Source this file in the prepared cloud machine. It does not change the checkout.
export PATH="/workspace/tools/flutter/bin:/workspace/tools/jvm/java-21-openjdk-amd64/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
export XDG_CONFIG_HOME=/workspace/.config
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
if [ -x /workspace/tools/jvm/java-21-openjdk-amd64/bin/javac ]; then
  export JAVA_HOME=/workspace/tools/jvm/java-21-openjdk-amd64
fi
if [ -d /workspace/tools/android-sdk ]; then
  export ANDROID_HOME=/workspace/tools/android-sdk
  export GRADLE_USER_HOME=/workspace/.gradle
fi
# Java/Gradle do not consume HTTPS_PROXY automatically. Reuse the managed proxy
# without copying any proxy credentials, and retain the current machine's CA trust.
if [ -n "${HTTPS_PROXY:-}" ]; then
  read -r tally_proxy_host tally_proxy_port < <(python3 - <<'PY'
import os, re
from urllib.parse import urlparse
proxy = urlparse(os.environ.get('HTTPS_PROXY', ''))
if proxy.hostname and re.fullmatch(r'[A-Za-z0-9.-]+', proxy.hostname):
    print(proxy.hostname, proxy.port or 80)
PY
  )
  if [ -n "${tally_proxy_host:-}" ] && [ -n "${tally_proxy_port:-}" ]; then
    export GRADLE_OPTS="${GRADLE_OPTS:-} -Dhttp.proxyHost=$tally_proxy_host -Dhttp.proxyPort=$tally_proxy_port -Dhttps.proxyHost=$tally_proxy_host -Dhttps.proxyPort=$tally_proxy_port -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts"
  fi
  unset tally_proxy_host tally_proxy_port
fi
