#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${APT_OUT_DIR:-${ROOT}/out}"
PAGES="${APT_PAGES_DIR:-${ROOT}/pages}"
URI="${APT_REPO_URI:-https://jochemkuipers.github.io/apt-repo}"
CODENAME="stable"

if [[ -z "${APT_SIGNING_KEY:-}" ]]; then
	echo "APT_SIGNING_KEY is required" >&2
	exit 1
fi
if [[ -z "${APT_SIGNING_KEY_PASSPHRASE:-}" ]]; then
	echo "APT_SIGNING_KEY_PASSPHRASE is required" >&2
	exit 1
fi

shopt -s nullglob
fetched=("${OUT}"/*.deb)
if (( ${#fetched[@]} == 0 )); then
	echo "No .deb files in ${OUT}" >&2
	exit 1
fi

already=0
if [[ -d "${PAGES}/pool" ]]; then
	already=1
	for deb in "${fetched[@]}"; do
		name="$(basename "${deb}")"
		if ! find "${PAGES}/pool" -name "${name}" -print -quit | grep -q .; then
			already=0
			break
		fi
	done
fi
if (( already )); then
	echo "All fetched debs already in pool; skip republish"
	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		echo "skip=true" >> "${GITHUB_OUTPUT}"
	fi
	exit 0
fi

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
chmod 700 "${GNUPGHOME}"
printf '%s\n' "${APT_SIGNING_KEY}" | gpg --batch --import
PASSPHRASE_FILE="${GNUPGHOME}/pass"
printf '%s' "${APT_SIGNING_KEY_PASSPHRASE}" > "${PASSPHRASE_FILE}"
chmod 600 "${PASSPHRASE_FILE}"
cat > "${GNUPGHOME}/gpg.conf" <<EOF
batch
pinentry-mode loopback
passphrase-file ${PASSPHRASE_FILE}
EOF
cat > "${GNUPGHOME}/gpg-agent.conf" <<EOF
allow-loopback-pinentry
EOF

KEYID="$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr:/ {print $10; exit}')"
if [[ -z "${KEYID}" ]]; then
	echo "Failed to import APT signing key" >&2
	exit 1
fi
gpg --batch --armor --export "${KEYID}" > "${GNUPGHOME}/public.asc"

WORKDIR="$(mktemp -d)"
if [[ -d "${PAGES}/pool" ]]; then
	find "${PAGES}/pool" -name '*.deb' -exec cp -a {} "${WORKDIR}/" \;
fi
cp -a "${OUT}"/*.deb "${WORKDIR}/"

rm -rf "${PAGES}"
mkdir -p "${PAGES}/conf"
cat > "${PAGES}/conf/distributions" <<EOF
Origin: Jochem Kuipers
Label: Jochem APT
Codename: ${CODENAME}
Architectures: amd64 arm64
Components: main
Description: Personal APT repository
SignWith: ${KEYID}
EOF
cat > "${PAGES}/conf/options" <<EOF
verbose
EOF

for deb in "${WORKDIR}"/*.deb; do
	reprepro -b "${PAGES}" --ignore=missingfield -S misc includedeb "${CODENAME}" "${deb}"
done

cp -a "${GNUPGHOME}/public.asc" "${PAGES}/jochem-archive-keyring.asc"
gpg --batch --dearmor --output "${PAGES}/jochem-archive-keyring.gpg" "${GNUPGHOME}/public.asc"

{
	cat <<EOF
Types: deb
URIs: ${URI}
Suites: ${CODENAME}
Components: main
Architectures: amd64 arm64
EOF
	awk '
		BEGIN { print "Signed-By:" }
		{
			if ($0 == "") print " ."
			else print " " $0
		}
	' "${GNUPGHOME}/public.asc"
} > "${PAGES}/jochem.sources"

cat > "${PAGES}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Jochem APT repository</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 44rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    pre { background: #111; color: #eee; padding: 1rem; overflow-x: auto; }
    code { font-family: ui-monospace, monospace; }
  </style>
</head>
<body>
  <h1>Jochem APT repository</h1>
  <p>Unofficial personal packages of howdy-next, adguard-tray, skills-manager, and uniwill-laptop.</p>
  <h2>Install</h2>
  <pre><code>curl -fsSL ${URI}/jochem.sources \\
  | sudo tee /etc/apt/sources.list.d/jochem.sources
sudo apt update
sudo apt install howdy-next adguard-tray skills-manager uniwill-laptop</code></pre>
</body>
</html>
EOF

touch "${PAGES}/.nojekyll"
rm -rf "${PAGES}/db" "${PAGES}/conf"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
	echo "skip=false" >> "${GITHUB_OUTPUT}"
fi

echo "APT repository written to ${PAGES}"
find "${PAGES}" -type f | sort
