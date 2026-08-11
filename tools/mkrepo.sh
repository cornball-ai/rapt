#!/bin/sh
#
# Rebuild the apt repository under docs/ from the .deb files given as
# arguments. Called from CI, and usable by hand to rebuild the indices.
#
#   Usage: mkrepo.sh <suite> <deb>...
#
# The repository is laid out per suite rather than flat, so that a jammy
# client is never offered a noble build:
#
#   docs/dists/<suite>/Release
#   docs/dists/<suite>/main/binary-<arch>/Packages
#   docs/pool/<suite>/main/r/rapt/rapt_<version>_<arch>.deb
#
# The repository is unsigned, so clients need 'Trusted: yes' in their .sources
# entry. To sign it instead, clearsign Release into InRelease and write a
# detached Release.gpg, then drop the plain copy below.

set -eu

if [ $# -lt 2 ]; then
    echo "usage: $0 <suite> <deb>..." >&2
    exit 2
fi

suite=$1
shift

repo="$(cd "${RAPT_REPO:-$(dirname "$0")/../docs}" && pwd)"
pool="pool/${suite}/main/r/rapt"

mkdir -p "${repo}/${pool}"
for deb in "$@"; do
    # apt-ftparchive picks packages by filename while everything below reads
    # metadata, so a package misnamed relative to its own control fields is
    # skipped from the index without complaint. Reject it at the door instead,
    # where the failure names the file rather than showing up as an absence.
    want="$(dpkg-deb -f "$deb" Package)_$(dpkg-deb -f "$deb" Version | sed 's/^[0-9]*://')_$(dpkg-deb -f "$deb" Architecture).deb"
    if [ "$(basename "$deb")" != "${want}" ]; then
        echo "$(basename "$deb") does not match its control fields, expected ${want}" >&2
        exit 1
    fi
    cp -vax "$deb" "${repo}/${pool}/"
done

cd "$repo"

# Architectures are read back off the pool rather than passed in, so a suite
# that gains or loses one needs no change here. Read from the package rather
# than parsed out of its name, which is only a convention.
arches=$(for f in "${pool}"/*.deb; do dpkg-deb -f "$f" Architecture; done | sort -u)

# Drop all but the newest few of each, or the pool grows without bound and
# Packages lists every build ever made.
keep=${RAPT_KEEP:-3}
for arch in ${arches}; do
    ls -1 "${pool}"/*_"${arch}".deb | sort -V | head -n "-${keep}" | while read -r old; do
        rm -v "${old}"
    done
done

for arch in ${arches}; do
    dir="dists/${suite}/main/binary-${arch}"
    mkdir -p "${dir}"
    apt-ftparchive --arch "${arch}" packages "${pool}" > "${dir}/Packages"
    gzip -9 -c "${dir}/Packages" > "${dir}/Packages.gz"
    # Belt and braces behind the filename check above: every package in the
    # pool for this architecture has to appear. A count rather than a mere
    # non-empty test, or one stale package left over from a previous publish
    # would mask a new one having been dropped.
    want=$(for f in "${pool}"/*.deb; do dpkg-deb -f "$f" Architecture; done |
               grep -cE "^(${arch}|all)$")
    got=$(grep -c '^Package:' "${dir}/Packages" || true)
    if [ "${want}" -ne "${got}" ]; then
        echo "${dir}/Packages lists ${got} of ${want} ${arch} packages in the pool" >&2
        exit 1
    fi
done

# Both are removed first because apt-ftparchive hashes every file it finds in
# the directory. Left in place, last publish's Release is hashed into this
# one, giving a stale self-checksum that describes nothing useful.
rm -f "dists/${suite}/Release" "dists/${suite}/InRelease"
apt-ftparchive -c repo.conf \
    -o APT::FTPArchive::Release::Suite="${suite}" \
    -o APT::FTPArchive::Release::Codename="${suite}" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Architectures="$(printf '%s' "${arches}" | tr '\n' ' ')" \
    release "dists/${suite}" > "dists/${suite}/.Release.tmp"
mv "dists/${suite}/.Release.tmp" "dists/${suite}/Release"
cp -a "dists/${suite}/Release" "dists/${suite}/InRelease"

find dists pool -type f | sort
