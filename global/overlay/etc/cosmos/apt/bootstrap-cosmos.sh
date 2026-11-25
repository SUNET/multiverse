#!/bin/bash
# Run as root from the protected bootstrap bundle sent by the controller.
set -euo pipefail
export LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
host=${1:?model hostname}
repo=${2:?Git URL}
tag=${3:?release tag prefix}
IFS=, read -ra overlays <<<"${4:-}"
valid_component() {
	local component=$1
	[[ $component =~ ^[[:alnum:]][[:alnum:]._-]*$ && $component != *..* ]]
}
valid_component "$host" && valid_component "$tag" || exit 2
for overlay in "${overlays[@]}"; do valid_component "$overlay" || exit 2; done
exec 200>/tmp/run-cosmos.lock
flock -w 120 200
. /etc/os-release
bash ./install-cosmos-package
cron=cron
if [[ $ID == almalinux ]]; then cron=crond; fi

checkout=/var/cache/cosmos/repo
if [[ ! -d $checkout ]]; then
	cosmos clone "$repo"
fi
if ((${#overlays[@]} == 0)); then
	overlays=("${host%%-*}-common")
fi
models=("\$COSMOS_REPO/$host/")
for overlay in "${overlays[@]}"; do
	if [[ -d $checkout/$overlay ]]; then
		models+=("\$COSMOS_REPO/$overlay/")
	fi
done
models+=("\$COSMOS_REPO/global/")
if [[ $ID == almalinux && -f /var/lib/multiverse/handoff-pending ]]; then
	# This session proved independent root access. Keep the original UID
	# and home while retiring login and the cloud user's sudo grants.
	usermod --lock --expiredate 1 --shell /usr/sbin/nologin almalinux
	if id -nG almalinux | tr ' ' '\n' | grep -Fxq wheel; then
		gpasswd -d almalinux wheel
	fi
	# cloud-init can put rules for several accounts in this file.
	sudoers=/etc/sudoers.d/90-cloud-init-users
	if [[ -f $sudoers ]]; then
		tmp=$(mktemp /etc/sudoers.d/.multiverse.XXXXXXXX)
		sed '/^almalinux[[:space:]]/d' "$sudoers" >"$tmp"
		chmod 0440 "$tmp"
		visudo -cf "$tmp"
		mv -f "$tmp" "$sudoers"
		restorecon "$sudoers"
	fi
	# sudo -l can return zero even when the user is denied every command.
	grants=$(LC_ALL=C sudo -n -l -U almalinux 2>&1) || true
	if [[ $grants != "User almalinux is not allowed to run sudo on "* ]]; then
		echo 'A site sudo rule still grants access to almalinux' >&2
		exit 1
	fi
	rm -f /var/lib/multiverse/handoff-pending
fi
hostnamectl set-hostname "$host"
if [[ -d /etc/cloud/cloud.cfg.d ]]; then
	printf 'preserve_hostname: true\nmanage_etc_hosts: false\n' >/etc/cloud/cloud.cfg.d/99-multiverse-hostname.cfg
fi
address=$(ip -j route get 192.0.2.1 2>/dev/null | jq -er '.[0].prefsrc') ||
	address=$(ip -6 -j route get 2001:db8::1 | jq -er '.[0].prefsrc')
awk -v h="$host" '$0 !~ /# multiverse-hostname$/ {
	for (i=2; i<=NF && $i !~ /^#/; i++) if ($i == h) next
	print
}' /etc/hosts >hosts.new
printf '%s %s %s # multiverse-hostname\n' "$address" "$host" "${host%%.*}" >>hosts.new
cat hosts.new >/etc/hosts

conf=/etc/cosmos/cosmos.conf
sed -E '/^#?COSMOS_(REPO_MODELS|UPDATE_VERIFY|UPDATE_VERIFY_GIT_TAG_PATTERN)=/d' "$conf" >cosmos.conf
(
	IFS=:
	printf 'COSMOS_REPO_MODELS="%s"\n' "${models[*]}"
) >>cosmos.conf
printf 'COSMOS_UPDATE_VERIFY=y\nCOSMOS_UPDATE_VERIFY_GIT_TAG_PATTERN="%s*"\n' "$tag" >>cosmos.conf
# Replace atomically on the same filesystem, retaining package permissions.
cp -p "$conf" "$conf.enrolling"
cat cosmos.conf >"$conf.enrolling"
mv -f "$conf.enrolling" "$conf"
env COSMOS_BASE=/var/cache/cosmos COSMOS_KEYS=/var/cache/cosmos/repo/global/overlay/etc/cosmos/keys /var/cache/cosmos/repo/global/post-tasks.d/015cosmos-trust

mkdir -p /var/cache/scriptherder
export COSMOS_PUPPET_RECEIPT="$PWD/catalog-applied"
rm -f "$COSMOS_PUPPET_RECEIPT"
{
	cosmos -v update
	cosmos -v apply
	[[ -s $COSMOS_PUPPET_RECEIPT ]] || {
		echo 'No successful Puppet apply in the signed model' >&2
		exit 1
	}
	systemctl enable --now "$cron"
	touch /run/last-cosmos-ok.stamp
	install -d -m 0700 /var/lib/multiverse
	touch /var/lib/multiverse/enrolled
	rm -f /var/lib/multiverse/enroll-pending
} 2>&1 | tee -a /var/log/cosmos.log
