# Build Cosmos for AlmaLinux 10

From the Multiverse checkout, run `make cosmos-rpm` with Docker and Buildx.
The builder uses a digest-pinned AlmaLinux 10 image and installs its build
dependencies with DNF. The build exports unsigned development artifacts to `build/cosmos-rpm/`.
The `rpm/` directory holds the signed release copies used for enrollment.

| File in `rpm/` | Contents |
| --- | --- |
| `cosmos-1.5-2.sunet.2.el10.noarch.rpm` | CLI, configuration, executable hooks, manual and license |
| `cosmos-1.5-2.sunet.2.el10.src.rpm` | Spec, upstream tarball and SUNET patch |

The release signing key in `rpm/kushal_rpm.pub` has fingerprint
`999E C8E3 14BC 8D46 022D 6C7D E217 C30C 3621 CD35`.
[Published public key](https://rpm.torproject.org/fedora/public_gpg.key)

The spec checks the SHA-256 of the vendored Cosmos 1.5 tarball against the
digest published for that release. The SUNET patch reproduces the changes
to the config and two Git update hooks in the bundled
`apt/cosmos_1.5-2~sunet20220414_all.deb`. Its branch detection supports
repositories that have moved away from master, and its update output
identifies the selected release. [Upstream releases](https://josefsson.org/cosmos/)

The build extracts the RPM and the bundled Debian package and compares the
CLI, default configuration and all hooks byte for byte and checks their
permission modes. RPM preserves local
configuration and hook edits with `%config(noreplace)`. Cosmos uses the same
hook selection rules on both systems. When merging an RPM upgrade, move
executable `.rpmnew` or `.rpmsave` files out of the hook directories before
running Cosmos.

The build tests an upgrade in a disposable container with modified local
configuration, a customized hook and a disposable trust key. It then runs
`cosmos clone`, `cosmos update` and `cosmos apply` against a local signed
model and checks host overlay precedence. A second signer exercises rejection
of an untrusted update. Package signing and VM enrollment are separate release
steps.

On an EL10 build host with the spec's build dependencies installed, rebuild
the binary directly from the source package:

```sh
rpmbuild --rebuild rpm/cosmos-1.5-2.sunet.2.el10.src.rpm
```

## VM verification

On 2026-11-25, a fresh AlmaLinux 10.3 x86_64 guest with SELinux enforcing
rejected the unsigned development RPM and enrolled with a copy signed by a
disposable test key. The installed RPM metadata matched the Debian package
on all 15 runtime file hashes and modes. Cosmos applied the host overlay and
OpenVox applied a Puppet resource. A second trusted release changed the
resource. An untrusted tag failed verification and left the resource and
success timestamp intact. A subsequent trusted release applied successfully.
After a reboot, the scheduled Cosmos run repaired deliberate drift in the
resource and wrote a fresh success timestamp.
