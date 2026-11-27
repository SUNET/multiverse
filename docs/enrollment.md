# Enroll a Debian or AlmaLinux host

Run these commands on the provisioning workstation in the ops repository.
Configure `repo` and `tag` in `cosmos.conf`, or provide the `ro` Git remote
for the read-only model URL. The host must be able to reach that URL.

| Controller input | Purpose |
| --- | --- |
| Verified SSH host key or host CA, SSH identity | Authenticate the destination and the provisioning account. `COSMOS_SSH_CONFIG` can point to a separate OpenSSH configuration. |
| `rpm/cosmos-*.el10.noarch.rpm` and `rpm/kushal_rpm.pub` | AlmaLinux enrollment verifies the binary with the bundled key in an isolated RPM database, installs the key as `/etc/pki/rpm-gpg/RPM-GPG-KEY-cosmos`, and imports it into the system RPM database for DNF. Set `COSMOS_RPM_KEY` to select a different signing key for a local test build. |
| `COSMOS_PROVISIONING_PUBKEY` | Optional workstation public key for the AlmaLinux root handoff. Set it when the cloud image has no single provisioning key or the controller uses a different identity. |

Register the host and review its Git commit and signed tag. Add `-b` to enroll
it immediately, or rerun the command with `-b` after registration. The
destination can be an IP address before DNS is configured.

```sh
./addhost app-1.example.org
./addhost -b -n app-1.example.org -- 192.0.2.40
```

For a fresh AlmaLinux cloud guest behind a jump host:

```sh
./addhost -b -p admin@jump.example.org -n app-2.example.org -- 192.0.2.41
```

The controller tries root first. On a fresh AlmaLinux cloud image it uses the
single public key recorded by cloud-init if that key still has ordinary login
access as `almalinux`. An explicit `COSMOS_PROVISIONING_PUBKEY` selects the
operator's key instead. It adds the key to root and checks that a separate
SSH connection returns UID 0. It then locks
and expires the initial cloud account, removes its wheel membership and its
cloud-init sudo grant, and checks for additional sudo grants. Its UID, home
and other accounts' access are preserved. A retry uses the verified root
connection and can finish an interrupted handoff.

On both distributions, bootstrap uses `cosmos clone` and runs the checkout's
`global/post-tasks.d/015cosmos-trust` to import the initial model keys from
`global/overlay/etc/cosmos/keys/`. The initial clone is trusted at this step.
`cosmos update` then verifies the release tag before `cosmos apply` applies
the host, additional group and global overlays in precedence order. Without explicit overlays it uses the legacy host-prefix common
directory when available. Supply signed Git modules through
`overlay/etc/puppet/cosmos-modules.conf`. Each row has a name, Git URL,
update flag and tag pattern. AlmaLinux uses the EL10 OpenVox 8 agent. The
ENC, Puppet config, module paths and Hiera hierarchy live under `/etc/puppet`
on both distributions. OpenVox package and repository signatures are checked
with its published key from the signed model.
[OpenVox repository signing key](https://docs.openvoxproject.org/openvox/8.x/mirrors.html)

## Verify or recover an enrollment

As root on the enrolled host, inspect the first apply and the scheduled run:

```sh
hostnamectl --static
getent ahosts "$(hostname -f)"
tail -n 50 /var/log/cosmos.log
cat /etc/cron.d/cosmos
stat /run/last-cosmos-ok.stamp
git -C /var/cache/cosmos/repo rev-parse HEAD
```

Check a resource from your catalog and the encrypted Hiera lookup it uses.
To check that a secret resolves, suppress its value in the shell output:

```sh
. /etc/os-release
puppet=/usr/bin/puppet
if [ "$ID" = almalinux ]; then puppet=/opt/puppetlabs/bin/puppet; fi
"$puppet" lookup --confdir /etc/puppet --hiera_config /etc/puppet/hiera.yaml \
    --node "$(hostname -f)" example::encrypted_setting >/dev/null
```

The boot and 15-minute cron entries invoke the same serialized `run-cosmos`
used for manual convergence. During enrollment, a failed model update, missing catalog receipt or Puppet
resource error fails the first apply. Inspect
the controller error and `/var/log/cosmos.log`, correct the input or publish
a reviewed signed fix, and rerun the original enrollment command. For a
later scheduled failure, run `/usr/local/bin/run-cosmos -v` as root and
check the new success stamp.

## Validation history

The integration run preceding the review split used Debian 13 and an enforcing
AlmaLinux 10.3 guest, OpenVox 8.34.0 and a test-signed Cosmos RPM. The guests
applied an encrypted Hiera value and reconverged after reboot. A live Nova
launch, volume attachment and DNS update remain unverified.
