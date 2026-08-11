#!/bin/sh
#
# Regression tests for tools/mkrepo.sh. Builds throwaway packages in a temp
# directory and publishes into a temp repository, so it touches nothing real.
#
#   Usage: tools/test-mkrepo.sh
#
# Needs dpkg-deb and apt-ftparchive, both of which the repository build
# already depends on.

set -eu

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

RAPT_REPO="${work}/docs"
export RAPT_REPO
mkdir -p "${RAPT_REPO}"
cp "${here}/../docs/repo.conf" "${RAPT_REPO}/"

pass=0
fail=0
ok ()   { pass=$((pass + 1)); echo "ok   - $1"; }
bad ()  { fail=$((fail + 1)); echo "FAIL - $1"; }
check () { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# Build a minimal .deb whose control fields match its filename.
mkdeb () { # $1 version, $2 arch, $3 output dir
    d="${work}/build/$1_$2"
    rm -rf "$d"; mkdir -p "$d/DEBIAN"
    printf 'Package: rapt\nVersion: %s\nArchitecture: %s\nMaintainer: t <t@e>\nDescription: test\n' \
        "$1" "$2" > "$d/DEBIAN/control"
    dpkg-deb --build -Znone "$d" "$3/rapt_$1_$2.deb" > /dev/null
}

mkdir -p "${work}/in"
mkdeb "0.1.1-1~noble" amd64 "${work}/in"

echo "# repeated publishes"
"${here}/mkrepo.sh" noble "${work}/in/rapt_0.1.1-1~noble_amd64.deb" > /dev/null
"${here}/mkrepo.sh" noble "${work}/in/rapt_0.1.1-1~noble_amd64.deb" > /dev/null
"${here}/mkrepo.sh" noble "${work}/in/rapt_0.1.1-1~noble_amd64.deb" > /dev/null

rel="${RAPT_REPO}/dists/noble/Release"
selfref=$(grep -cE '[0-9a-f]{64} +[0-9]+ (Release|InRelease)$' "${rel}" || true)
check "Release does not hash itself after repeat publishes" "${selfref}" "0"

indexed=$(grep -cE '^ [0-9a-f]{64} +[0-9]+ main/binary-amd64/Packages$' "${rel}" || true)
check "Release hashes the Packages index" "${indexed}" "1"

check "suite is declared" "$(grep -c '^Suite: noble$' "${rel}")" "1"
check "component is declared" "$(grep -c '^Components: main$' "${rel}")" "1"

echo "# a second architecture"
mkdeb "0.1.1-1~noble" arm64 "${work}/in"
"${here}/mkrepo.sh" noble "${work}/in/rapt_0.1.1-1~noble_arm64.deb" > /dev/null
check "arm64 index exists" \
    "$(grep -c '^Package: rapt$' "${RAPT_REPO}/dists/noble/main/binary-arm64/Packages")" "1"
check "amd64 index unaffected" \
    "$(grep -c '^Package: rapt$' "${RAPT_REPO}/dists/noble/main/binary-amd64/Packages")" "1"
check "both architectures declared" \
    "$(grep -c '^Architectures: amd64 arm64$' "${RAPT_REPO}/dists/noble/Release")" "1"

echo "# suites stay separate"
mkdeb "0.1.1-1~jammy" amd64 "${work}/in"
"${here}/mkrepo.sh" jammy "${work}/in/rapt_0.1.1-1~jammy_amd64.deb" > /dev/null
check "jammy index holds only the jammy build" \
    "$(grep -c 'jammy' "${RAPT_REPO}/dists/jammy/main/binary-amd64/Packages")" "2"
check "noble index has no jammy build" \
    "$(grep -c 'jammy' "${RAPT_REPO}/dists/noble/main/binary-amd64/Packages" || true)" "0"

echo "# a package misnamed relative to its control fields is refused"
cp "${work}/in/rapt_0.1.1-1~noble_amd64.deb" "${work}/in/wrong-name.deb"
if "${here}/mkrepo.sh" noble "${work}/in/wrong-name.deb" > /dev/null 2>&1; then
    bad "misnamed package was accepted"
else
    ok "misnamed package was refused"
fi

echo "# pruning keeps the newest few"
for v in 0.1.2-1~noble 0.1.3-1~noble 0.1.4-1~noble 0.1.5-1~noble; do
    mkdeb "$v" amd64 "${work}/in"
    "${here}/mkrepo.sh" noble "${work}/in/rapt_${v}_amd64.deb" > /dev/null
done
kept=$(ls -1 "${RAPT_REPO}"/pool/noble/main/r/rapt/*_amd64.deb | wc -l)
check "pool keeps three amd64 builds" "${kept}" "3"
check "oldest was dropped" \
    "$(ls "${RAPT_REPO}"/pool/noble/main/r/rapt/ | grep -c '0.1.1-1~noble_amd64' || true)" "0"
check "index matches the pruned pool" \
    "$(grep -c '^Package: rapt$' "${RAPT_REPO}/dists/noble/main/binary-amd64/Packages")" "3"

echo "# publish.sh groups a downloaded artifact tree by suite"
rm -rf "${RAPT_REPO}/dists" "${RAPT_REPO}/pool"
for pair in jammy:amd64 noble:amd64 noble:arm64 resolute:amd64 resolute:arm64; do
    s=${pair%:*}; a=${pair#*:}
    mkdir -p "${work}/incoming/deb-${s}-${a}"
    mkdeb "0.1.2-1~${s}" "${a}" "${work}/incoming/deb-${s}-${a}"
done
"${here}/publish.sh" "${work}/incoming" > /dev/null

check "jammy has one architecture" \
    "$(ls -1 "${RAPT_REPO}/dists/jammy/main" | wc -l)" "1"
check "noble has two architectures" \
    "$(ls -1 "${RAPT_REPO}/dists/noble/main" | wc -l)" "2"
check "resolute has two architectures" \
    "$(ls -1 "${RAPT_REPO}/dists/resolute/main" | wc -l)" "2"
check "noble Release declares both" \
    "$(grep -c '^Architectures: amd64 arm64$' "${RAPT_REPO}/dists/noble/Release")" "1"
check "no jammy build leaked into noble" \
    "$(grep -c 'jammy' "${RAPT_REPO}/dists/noble/main/binary-amd64/Packages" || true)" "0"

echo "# publish.sh refuses an empty tree rather than reporting success"
mkdir -p "${work}/empty"
if "${here}/publish.sh" "${work}/empty" > /dev/null 2>&1; then
    bad "empty artifact tree was accepted"
else
    ok "empty artifact tree was refused"
fi

# The publish job commits with 'git add -A docs', so a .gitignore rule that
# covers the pool drops every package while still committing the indices that
# name them. That publishes a repository which resolves and then 404s, and
# nothing in the run fails. Ask git directly rather than trusting the pattern
# to keep matching the layout.
echo "# the real .gitignore does not swallow pool packages"
repo_root="$(cd "${here}/.." && pwd)"
ignored=0
for pair in jammy:amd64 noble:amd64 noble:arm64 resolute:amd64 resolute:arm64; do
    s=${pair%:*}; a=${pair#*:}
    p="${repo_root}/docs/pool/${s}/main/r/rapt/rapt_0.1.2-1~${s}_${a}.deb"
    git -C "${repo_root}" check-ignore -q "$p" 2>/dev/null && ignored=$((ignored + 1))
done
check "no suite's pool packages are ignored" "${ignored}" "0"

echo
echo "${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
