FROM almalinux:10@sha256:ccf217024b3d5e268cc208d1edb384a1edee6359370cf6ea1ecbc42254e57375 AS build
RUN dnf -y install rpm-build make patch && dnf clean all
WORKDIR /root/rpmbuild
COPY cosmos-1.5.tar.gz sunet-git-update.patch SOURCES/
COPY cosmos.spec SPECS/
RUN rpmbuild -bs SPECS/cosmos.spec

FROM build AS binary
RUN rpmbuild --define "_topdir /tmp/rebuild" --rebuild SRPMS/*.src.rpm

# Compare the rebuilt RPM's complete runtime with the bundled Debian package.
RUN --mount=from=multiverse-apt,target=/apt \
    mkdir /tmp/rpm-files /tmp/deb-files && \
    cd /tmp/rpm-files && rpm2cpio /tmp/rebuild/RPMS/noarch/*.rpm | cpio -idm && \
    cd /tmp/deb-files && ar p /apt/cosmos_1.5-2~sunet20220414_all.deb data.tar.xz | tar -xJ && \
    cmp usr/bin/cosmos /tmp/rpm-files/usr/bin/cosmos && \
    diff -r etc/cosmos /tmp/rpm-files/etc/cosmos && \
    find usr/bin/cosmos etc/cosmos -printf '%p %m\n' | sort >/tmp/deb-modes && \
    cd /tmp/rpm-files && find usr/bin/cosmos etc/cosmos -printf '%p %m\n' | sort >/tmp/rpm-modes && \
    diff /tmp/deb-modes /tmp/rpm-modes

# Make an older fixture with a different packaged default to exercise a real upgrade.
FROM build AS previous
RUN sed -e 's/^Release:.*/Release:        0.fixture%{?dist}/' \
        -e '/^%check/i echo "# Previous packaged default" >> %{buildroot}%{_sysconfdir}/cosmos/cosmos.conf' \
        SPECS/cosmos.spec > SPECS/previous.spec && rpmbuild -bb SPECS/previous.spec

FROM almalinux:10@sha256:ccf217024b3d5e268cc208d1edb384a1edee6359370cf6ea1ecbc42254e57375 AS check
COPY --from=binary /tmp/rebuild/RPMS/noarch/*.rpm /packages/
COPY --from=build /root/rpmbuild/SRPMS/*.src.rpm /packages/
COPY --from=previous /root/rpmbuild/RPMS/noarch/*fixture*.rpm /tmp/previous.rpm
RUN dnf -y install /tmp/previous.rpm && dnf clean all
COPY check-installed.sh /tmp/
RUN bash /tmp/check-installed.sh

FROM scratch
COPY --from=check /packages/ /
USER 65534:65534
