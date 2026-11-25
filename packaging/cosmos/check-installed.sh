#!/bin/bash
# Runs only in the disposable EL10 package-test image.
set -euo pipefail
cd "$(mktemp -d)"
mkdir -m 0700 signer
export GNUPGHOME="$PWD/signer"
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key 'Cosmos package test <cosmos@example.invalid>' rsa2048 sign 1d
gpg --export | cosmos gpg --batch --import

# Exercise upgrade semantics with locally edited config, a custom hook and keys.
mkdir -p /etc/cosmos/keys
gpg --armor --export > /etc/cosmos/keys/test.pub
cat >> /etc/cosmos/cosmos.conf <<CONF
COSMOS_BASE="$PWD/cache"
COSMOS_REPO="\$COSMOS_BASE/repo"
COSMOS_MODEL="\$COSMOS_BASE/model"
COSMOS_REPO_MODELS="\$COSMOS_REPO/node/:\$COSMOS_REPO/global/"
COSMOS_ROOT="$PWD/target"
COSMOS_UPDATE_VERIFY_GIT_TAG_PATTERN="package-test-*"
CONF
conf=/etc/cosmos/cosmos.conf
hook=/etc/cosmos/update.d/10repo-test
echo '# local hook customization' >> "$hook"
sha256sum "$conf" "$hook" /etc/cosmos/keys/test.pub > local-files.sha256
rpm -Uvh /packages/*.noarch.rpm
sha256sum -c local-files.sha256
test -s "$conf.rpmnew"
rpm -q --qf '%{ARCH}\n' cosmos | grep -Fx noarch
cosmos --version 2>&1 | grep -Fx 'cosmos (Cosmos) 1.5'

mkdir -p cache target model/{node,global}/overlay
git init -q -b main model
git -C model config user.name 'Package test'
git -C model config user.email cosmos@example.invalid
echo global > model/global/overlay/marker
echo node > model/node/overlay/marker
git -C model add .
git -C model commit -qm initial
git -C model tag -s -m first package-test-01

# Use Cosmos's normal HTTPS clone entry point with an isolated local transport.
git config --global url."file://$PWD/model".insteadOf https://example.invalid/model
cosmos clone https://example.invalid/model
cosmos update > update.log
test "$(git -C cache/repo rev-parse HEAD)" = "$(git -C model rev-parse package-test-01^{commit})"
cosmos apply
grep -Fx node target/marker

# Reject an untrusted annotated tag and retain the last verified model.
echo untrusted > model/node/overlay/marker
git -C model commit -qam second
mkdir -m 0700 other-signer
export GNUPGHOME="$PWD/other-signer"
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key 'Other test signer <other@example.invalid>' rsa2048 sign 1d
git -C model -c user.name="Other test signer" -c user.email=other@example.invalid tag -s -m second package-test-02
if cosmos update > rejected.log 2>&1; then
    echo 'Unexpectedly accepted a tag signed by an untrusted key' >&2
    exit 1
fi
grep -F 'Signature validation of tag package-test-02' rejected.log
grep -Fx node cache/model/overlay/marker
