#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${APT_OUT_DIR:-${ROOT}/out}"

mkdir -p "${OUT}"
rm -f "${OUT}"/*.deb

gh release download -R JochemKuipers/howdy-next-apt \
	--pattern 'howdy-next_*.deb' -D "${OUT}" --clobber
gh release download -R JochemKuipers/adguard-tray \
	--pattern 'adguard-tray_*.deb' -D "${OUT}" --clobber
gh release download -R JochemKuipers/uniwill-laptop \
	--pattern 'uniwill-*.deb' -D "${OUT}" --clobber

# Optional: upstream may not ship both arches on every release.
gh release download -R xingkongliang/skills-manager \
	--pattern 'skills-manager_*_amd64.deb' -D "${OUT}" --clobber || true
gh release download -R xingkongliang/skills-manager \
	--pattern 'skills-manager_*_arm64.deb' -D "${OUT}" --clobber || true

shopt -s nullglob
debs=("${OUT}"/*.deb)
if (( ${#debs[@]} == 0 )); then
	echo "No .deb files downloaded" >&2
	exit 1
fi

ls -l "${OUT}"/*.deb
