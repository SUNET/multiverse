
<div align="left">
  <img src="images/maestro_logo.png" width="50%">
</div>

# What is Maestro?

It's a set of orchestration tools to easier create hosts in Openstack, bootstrap cosmos and register in DNS (via knotctl). It also handles security groups, additional overlays and extra data volumes.

# Wooo! Sounds awesome. What do I need in order to use it?

* A modern version of multiverse which contains Maestro
* Ansible
* knotctl 0.1.10 or newer with access to given zone(s) (Optional but probably preferred). Older versions exit 0 even when the DNS API cannot be reached or does not answer in JSON; Maestro still warns in that case, but only from knotctl's output
* SUNET VPN (The Openstack APIs are protected)
* A modern version of the openstack collection to ansible (`ansible-galaxy collection install openstack.cloud --upgrade`)
* `clouds.yaml` which contains all the required sites

# Configuration
* Copy the examples files in `<ops-repo>/docs/maestro/` to `<ops-repo>/maestro/host_vars/localhost/` and make edits to match your repo/service (remove the example suffix from file names)
* Make sure that your clouds (sites) in [clouds.yaml](https://docs.my-aweseome-exampleen.cloud/en/latest/openstack/clouds.yaml.html) are named so Maestro can find them. That is `<project>-<service-provider>-<site>`. E.g. `example.sunet.se-safespring-dco`. The cloud names are part of the ops repo (`servers.yml` and `security_groups.yml` reference them), so every operator running Maestro from the same repo needs the same names in their own `clouds.yaml`. So following the same naming convention is strongly recommended.

```
clouds:
  example.sunet.se-safespring-dco:
    auth:
      auth_url: https://v2.api.dco.safedc.net:5000/v3/
      application_credential_id: "8759694bc6522f94b299d8f9dbabb31c881fdd1d"
      application_credential_secret: "f3bbbd66a63d4bf1747940578ec3d0103530e21d"
    auth_type: v3applicationcredential
  example.sunet.se-safespring-sto3:
    auth:
      auth_url: https://login.sto3.safespring.com:5000/v3/
      application_credential_id: "8759694bc6522f94b299d8f9dbabb31c881fdd1d"
      application_credential_secret: "f3bbbd66a63d4bf1747940578ec3d0103530e21d"
    auth_type: "v3applicationcredential"
  example.sunet.se-safespring-sto1:
    auth:
      auth_url: https://v2.dashboard.sto1.safedc.net:5000/v3/
      application_credential_id: "8759694bc6522f94b299d8f9dbabb31c881fdd1d"
      application_credential_secret: "f3bbbd66a63d4bf1747940578ec3d0103530e21d"
    auth_type: "v3applicationcredential"

```

# Usage
* Edit the ansible configuration for desired security groups and servers in `maestro/host_vars/localhost/`

* Add the host(s) to the ops-repo (⚠️ without bootstrap)
```
./addhost my-aweseome-example.example.com
```

* Get yourself the maestro directory in the ops repo
```
cd maestro
```

* Run the smoketest playbook to test: api/cloud connectivity, security group references etc.
```
ansible-playbook smoketest.yml
```

* Add/update the desired security groups
```
ansible-playbook security_groups.yml
```

* Add/update the desired servers
```
ansible-playbook servers.yml
```

* Or do both in one go (security groups first, then servers)
```
ansible-playbook site.yml
```

# Limiting a run to one cloud

All three playbooks accept `cloud_limit`, a cloud name (or comma separated list) from `clouds.yaml`. Only the servers and security groups in those clouds are processed; without it everything is.
```
ansible-playbook smoketest.yml -e cloud_limit=example.sunet.se-sunet-orion
ansible-playbook security_groups.yml -e cloud_limit=example.sunet.se-sunet-orion
ansible-playbook servers.yml -e cloud_limit=example.sunet.se-sunet-orion,example.sunet.se-safespring-dco
```
A name that matches no configured cloud fails the run instead of silently doing nothing.

# Extra data volumes

A server can get extra Openstack volumes (on top of its boot volume) by listing them under `extra_volumes` in `servers.yml`:

```
    extra_volumes:
      - name: data              # required, unique per server
        size: 100               # GiB, required
        mount: /srv/data        # optional: format and mount via cloud-init
        fs: ext4                # optional, default ext4 (only used with mount)
        volume_type: ssd        # optional
        availability_zone: nova # optional
```

* Each volume is named `<host>-<name>` in Openstack.
* With `mount` the volume is formatted (only if it has no filesystem yet) and mounted by cloud-init at first boot, using the stable `/dev/disk/by-id/virtio-*` path and the `nofail` option. Without `mount` the volume is only attached.
* Volumes are attached when the instance is created. For an instance that already exists, running `servers.yml` creates and attaches the new volume, but does not format or mount it (cloud-init only runs at first boot), so do that by hand.
* Maestro never deletes these volumes, so the data survives if the instance is rebuilt. Remove them manually in Openstack when no longer needed.
* Changing `size` of an existing volume is not handled by Maestro.

# Integration with knotctl

If a user has `knotctl` installed and configured and `knotctl user` returns the zone as the fqdn for the new server `knotctl` will automatically add the newly created host to DNS. If the host already exist in DNS the fqdn will not be updated. This behavior might change in the future if knotctl get the sync improved.

If `knotctl` is missing, fails, or does not return JSON for `knotctl --json user`, the hosts are still created, no DNS records are added, and the run prints a `[WARNING]` with knotctl's own output. Update DNS by hand for those hosts.

For every newly created host it reads the records back and compares them with the addresses the instance actually has, so the run reports what is published (`DNS now 130.242.0.1, 2001:6b0:... (added ...)`) and warns if an address is still missing. A run that ends with no `[WARNING]` lines has its DNS in place; any warning names the host to fix by hand.
