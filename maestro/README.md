# Maestro

Maestro is a set of Ansible playbooks that create hosts in OpenStack, bootstrap cosmos and register them in DNS (via knotctl). It also manages security groups.

## Setup

Needs [uv](https://docs.astral.sh/uv/) (it fetches Python 3.14 if missing) and a `~/.config/openstack/clouds.yaml`. From this directory (`maestro/`):

```sh
uv sync   # ansible-core, python-openstackclient, knotctl (pinned in uv.lock) into .venv
uv run ansible-galaxy collection install -r requirements.yml
uv run ansible-playbook smoketest.yml
```

## Usage

Run the playbooks in this order:

1. `smoketest.yml`: checks credentials and configuration
2. `security_groups.yml`
3. `servers.yml`

Run any playbook with `uv run ansible-playbook <playbook>.yml`.

`host_vars/` is project-specific and maintained downstream. Keep your changes there; changes to other files may conflict when you update from upstream.

## Ansible OpenStack Collection

The playbooks use the `openstack.cloud` collection.

```sh
uv run ansible-doc -l | grep openstack.cloud
```

In particular, the following modules are used:

- [`openstack.cloud.server`](https://docs.ansible.com/projects/ansible/latest/collections/openstack/cloud/server_module.html) - Create, delete, or manage OpenStack servers.
- [`openstack.cloud.port`](https://docs.ansible.com/projects/ansible/latest/collections/openstack/cloud/port_module.html) - Create, delete, or manage OpenStack ports.
- [`openstack.cloud.server_info`](https://docs.ansible.com/projects/ansible/latest/collections/openstack/cloud/server_info_module.html) - Gather information about OpenStack servers.

To see which options a module accepts, use `ansible-doc`:

```sh
uv run ansible-doc openstack.cloud.security_group
uv run ansible-doc openstack.cloud.server
uv run ansible-doc openstack.cloud.port
```
