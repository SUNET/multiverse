# Preserve the interpreter paths from the bundled Debian package.
%undefine __brp_mangle_shebangs

Name:           cosmos
Version:        1.5
Release:        2.sunet.2%{?dist}
Summary:        Apply a signed Git configuration model to a host
Packager:       kushal@sunet.se
License:        GPL-3.0-or-later
URL:            https://josefsson.org/cosmos/
Source0:        https://josefsson.org/cosmos/cosmos-%{version}.tar.gz
Patch0:         sunet-git-update.patch
BuildArch:      noarch
BuildRequires:  make
BuildRequires:  patch
Requires:       coreutils
Requires:       findutils
Requires:       git-core
Requires:       gnupg2
Requires:       rsync

%description
Cosmos assembles per-host configuration models from Git, verifies signed
release tags, installs overlays and executes the model's administration tasks.

%prep
echo '6456d38372d070c98853cdf3ea4ee96681551dc24c26dc8b06733088f3a4ce08  %{SOURCE0}' | sha256sum -c -
%autosetup -p1

%install
%make_install -o cosmos.1 prefix=%{_prefix}
chmod 0644 %{buildroot}%{_sysconfdir}/cosmos/cosmos.conf %{buildroot}%{_mandir}/man1/cosmos.1

%check
./cosmos --version 2>&1 | grep -Fx 'cosmos (Cosmos) %{version}'
for hook in cosmos *.d/*; do
    /bin/bash -n "$hook" || exit 1
done

%files
%license COPYING
%doc AUTHORS NEWS README
%{_bindir}/cosmos
%{_mandir}/man1/cosmos.1*
%dir %{_sysconfdir}/cosmos
%config(noreplace) %{_sysconfdir}/cosmos/cosmos.conf
%dir %{_sysconfdir}/cosmos/apply.d
%dir %{_sysconfdir}/cosmos/clone.d
%dir %{_sysconfdir}/cosmos/gpg.d
%dir %{_sysconfdir}/cosmos/update.d
%config(noreplace) %{_sysconfdir}/cosmos/*.d/*

%changelog
* Wed Nov 25 2026 Kushal Das <kushal@sunet.se> - 1.5-2.sunet.2
- Match the Cosmos runtime in the Multiverse Debian package.

* Tue Nov 24 2026 Kushal Das <kushal@sunet.se> - 1.5-2.sunet.1
- Package Cosmos 1.5 with the SUNET Git update hooks for EL10.
