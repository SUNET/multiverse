#!/usr/bin/env bash

set -e
set -u

hiera_dir=/etc/hiera/eyaml
shared_key=${hiera_dir}/shared-cosmos.pkcs7.key
shared_pem=${hiera_dir}/shared-cosmos.pkcs7.pem

while getopts "h:o:" option; do
  case "${option}" in
    h)
       host=${OPTARG}
        ;;
    o)
       overlay=${OPTARG}
        ;;
    ?)
       echo "Unsupported option" >&2
       exit 1
       ;;
  esac
done


if [ ! -d "${host}" ]; then
    echo "$0: No host-directory for '$host' found - execute in top-level cosmos dir"
    exit 1
fi

if [ ! -d "${overlay}" ]; then
    echo "$0: No overlay-directory for '$overlay' found - execute in top-level cosmos dir"
    exit 1
fi

if ssh -t root@"${host}" test -f "${shared_key}"; then
    echo "Secret key (${shared_key}) already exist. Not overwriting!"
    exit 1
fi
ssh -t root@"${host}" openssl req -x509 -newkey rsa:4096 -keyout "${shared_key}" -out "${shared_pem}" -days 3653 -nodes -sha256 -subj "/C=SE/O=SUNET/OU=EYAML/CN=shared-cosmos-${overlay}"

mkdir -p "${overlay}/overlay${hiera_dir}"
scp root@"${host}:${shared_pem}" "${overlay}/overlay${hiera_dir}"
git add "${overlay}/overlay${shared_pem}"

key=$(ssh -t root@"${host}" cat "${shared_key}")


echo
echo "Please add the following to hiera (./edit-secrets) on all machines using the ${overlay} overlay:"
echo

echo "shared_cosmos_hiera_key: >
        DEC::PKCS7[$key
]!"

echo
echo
echo
echo
echo "Don't forget to commit!"
