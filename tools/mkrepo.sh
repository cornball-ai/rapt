#!/bin/sh
#
# Rebuild the flat apt repository under docs/ from the .deb files given as
# arguments. Called from CI, and usable by hand to rebuild the indices.
#
# The repository is unsigned, so clients need 'Trusted: yes' in their .sources
# entry. To sign it instead, clearsign Release into InRelease and write a
# detached Release.gpg, then drop the plain copy below.

set -eu

repo="$(cd "$(dirname "$0")/../docs" && pwd)"

for deb in "$@"; do
    cp -vax "$deb" "$repo/"
done

cd "$repo"

# Drop all but the newest few, or docs/ grows without bound and Packages
# lists every build ever made.
keep=${RAPT_KEEP:-3}
ls -1 rapt_*.deb 2>/dev/null | sort -V | head -n "-${keep}" | while read -r old; do
    rm -v "$old"
done

apt-ftparchive packages . > Packages
gzip -9 -c Packages > Packages.gz
apt-ftparchive -c repo.conf release . > Release
cp -vax Release InRelease
ls -l
