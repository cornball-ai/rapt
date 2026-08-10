#!/bin/sh
#
# Publish every suite found in a downloaded artifact tree.
#
#   Usage: publish.sh <incoming-dir>
#
# Expects the layout actions/download-artifact produces from the build matrix:
#
#   <incoming-dir>/deb-<suite>-<arch>/rapt_<version>_<arch>.deb
#
# Suites are read off the directory names rather than hardcoded, so the matrix
# can gain or lose one without this changing.

set -eu

incoming=${1:-}
if [ -z "${incoming}" ]; then
    echo "usage: $0 <incoming-dir>" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"

suites=""
for dir in "${incoming}"/deb-*; do
    [ -d "${dir}" ] || continue
    name="$(basename "${dir}")"
    name=${name#deb-}
    suite=${name%-*}
    case " ${suites} " in
        *" ${suite} "*) ;;
        *) suites="${suites} ${suite}" ;;
    esac
done

published=0
for suite in ${suites}; do
    debs=$(find "${incoming}" -path "*/deb-${suite}-*/*.deb")
    [ -n "${debs}" ] || continue
    # Unquoted on purpose: one call per suite carrying all of its
    # architectures, so mkrepo.sh indexes them together.
    # shellcheck disable=SC2086
    "${here}/mkrepo.sh" "${suite}" ${debs}
    published=$((published + 1))
done

# A matrix that produced nothing, or artifact names that stopped matching, would
# otherwise commit an unchanged repository and look like a successful publish.
if [ "${published}" -eq 0 ]; then
    echo "no packages found under ${incoming}" >&2
    exit 1
fi

echo "published ${published} suites:${suites}"
