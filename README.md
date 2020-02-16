# k8senv

## Summary

Welcome to the `k8senv` simple developer environment installation for Kubernetes using `ansible`.  Please note that this is designed to only work with `Debian` derivatives eg: `Ubuntu`, and has been tested on Ubuntu 19.04.

## Build a Kubernetes Cluster

Please ensure that you have installed [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu).

The playbook is then run by using `make`:
```
$ make build
```

First you must adjust the `/inventory/hosts` file to reflect your available cluster.  There must be at least one host (a single node cluster) specified in the `master` group.  Ensure the nominates host/s and user are correctly specified and that ssh, and passwordless sudo access works.  Test this with (run from the repo root):
```
ansible -i ./inventory cluster -b -m shell -a  "hostname;whoami"
```

The variables to check/amend are:
```
[all:vars]
ansible_user=piers
ansible_python_interpreter=python3
ansible_ssh_private_key_file=/home/piers/.ssh/id_rsa
ansible_ssh_common_args='-o ControlPersist=30m -o StrictHostKeyChecking=no -o BatchMode=yes -q'
```

Environment variables for the deployment are:
* `DEBUG` [default: `false`] - turn on debug output for the driver by setting this to `true`
* `NVIDIA` [default: `false`] - enable Nvidia support by setting this to `true`
* `CONTAINERD` [default: `true`] - disable containerd installation by setting this to `false`.  Note this will also disable Nvidia support.

Use `make`, these values can be passed in with:
```
$ make deploy DEBUG=true
```

## Makefile usage

The `Makefile` does a lot of things, including installing Docker, containerd, Kubernetes and reseting the install, so type `make` to see:
```
$ make
make targets:
Makefile:all                   alias for build
Makefile:clean                 alias for reset
Makefile:help                  show this help.
Makefile:reset                 Reset Kubernetes installation  **CAUTION** this wipes iptables

make vars (+defaults):
Makefile:CONTAINERD            true
Makefile:DEBUG                 false
Makefile:LIMIT ?=              
Makefile:NVIDIA                false
```

## Tearing down the Kubernetes cluster

The cluster can be destroyed using:
```
$ make reset
```
