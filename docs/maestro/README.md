# What is Maestro?

It's a set of orchestration tools to easier create hosts in Openstack, bootstrap cosmos and register in DNS (via knotctl). It also handles security groups.

# Wooo! Sounds awesome. What do I need in order to use it?

* A modern version of multiverse which contains Maestro
* Ansible
* A modern version knotctl with access to given zone(s) (Optional but probably preferred)
* SUNET VPN (The Openstack APIs are protected)
* A modern version of the openstack collection to ansible (`ansible-galaxy collection install openstack.cloud --upgrade`)
* clouds.yaml which contains all the required sites

# Configuration
* Copy the examples files in `<ops-repo>/docs/maestro/` to `<ops-repo>/maestro/host_vars/localhost/` and make edits to match your repo/service (remove the example suffix from file names)
* Make sure that your clouds (sites) in [clouds.yaml](https://docs.my-aweseome-exampleen.cloud/en/latest/openstack/clouds.yaml.html) are named so Maestro can find them. That is `<project>-<service-provider>-<site>`. E.g. `example.sunet.se-safespring-dco`.

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

* Run the smoketest playbook connectivity against all configed sites (based on sites for security groups)
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

# Integration with knotctl
TBA
