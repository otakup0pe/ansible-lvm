[![Maintenance](https://img.shields.io/maintenance/yes/2026.svg)]()

Ansible / LVM Mashup
--------------------

I've had various incantations of this over the past few years for side projects, but here it is as something MIT licensed. You can use this Ansible role to create both LUKS encrypted and unencrypted logical volumes. The role will handle the creation of your volume group as well, if needed.

The role is entirely variable driven. You can simply include the role and pass in variables and it will handle the rest. The following example would setup two one gig logical volumes, with one being encrypted.

# Requirements

Install the `community.general`, `community.crypto`, and `ansible.posix`
collections on the controller. No extra controller-side Python package is
required for `community.crypto.luks_device`.

Managed hosts need `lvm2`, `cryptsetup`, `util-linux` (for `lsblk` and
`wipefs`), and `e2fsprogs`. This role configures storage but does not install
those system packages.

```
- role: lvm
  pv: "/dev/sdb"
  vg: "test-volume"
  lvm_encfs:
  - mnt: "encrypted"
    size: "1"
    key: "key.txt"
  lvm_plain:
  - mnt: "clear"
    size: "1"
```

That mounts `/mnt/encrypted` and `/mnt/clear`.

# Note About Crypto

The LUKS key is intentionally _not_ retained on hosts. The role stages it only while opening or resizing an encrypted volume and removes it even when that work fails. By default, encrypted volumes therefore need another `ansible-playbook` run after reboot. The key must be accessible on the executing workstation.

# Attributes

* `vg` is the name of the volume group.
* `pv` is a list of physical volumes to use for the volume group. Omit it to
  use a volume group that already exists.
* `lvm_crypt_suffix` is the suffix to append to the intermediary encrypted volume.
* `lvm_key_source` dictates where to look for keys.
* `lvm_key_dest` dictates where to stage keys during provisioning.
* `lvm_key_dest_mode` controls that directory mode and defaults to the existing `0400` behavior.
* `lvm_default_mnt_prefix` is the directory volumes mount under. Defaults to `/mnt`.

## `lvm_encfs` and `lvm_plain`

This is a list of YAML objects representing logical volumes. Each entry _must_ have the following items.

* `mnt` the volume name, which is also the basename of its mount point. Pass a
  bare name rather than a path -- the role joins it onto the mount prefix.
* `size` in whole gigabytes, as a bare number. The role appends the unit.

Each entry _may_ also have:

* `mnt_prefix` to mount this one volume somewhere other than
  `lvm_default_mnt_prefix`.
* `boot` to control whether the volume mounts at boot. `lvm_encfs` entries
  default to `true`; `lvm_plain` entries are always `false` and ignore this.

The `lvm_encfs` object _must_ also have a `key` value. Keys will receive a `.key` suffix and searched for under `lvm_key_source`.

# Prometheus Metrics

Optionally, the role can install a Prometheus
[textfile collector](https://github.com/prometheus/node_exporter#textfile-collector).
It is disabled by default; set `lvm_metrics_enabled` to `true` to enable it.

Each role invocation writes an expectation fragment for its `vg`,
`lvm_plain`, and `lvm_encfs` values. Fragments accumulate in
`lvm_metrics_expectations_dir`, so one collector reports all volume groups
managed by separate role invocations. The derived
`lvm_metrics_expected_vgs`, `lvm_metrics_expected_plain_lvs`, and
`lvm_metrics_expected_encrypted_lvs` variables can be overridden when a
caller needs a different expectation set.

Exported metrics:

* `lvm_vg_free_bytes{vg="..."}` -- free space in a present volume group.
* `lvm_vg_size_bytes{vg="..."}` -- total size of a present volume group.
* `lvm_expected_vg_present{vg="..."}` -- presence of an expected volume group.
* `lvm_expected_lv_present{vg="...",lv="..."}` -- presence of an expected logical volume.
* `lvm_expected_mapper_present{vg="...",lv="...",mapper="..."}` -- presence of an expected encrypted mapper.
* `lvm_metrics_scrape_success` -- `1` if the collector ran cleanly, `0` on error.
* `lvm_metrics_last_run_timestamp` -- unix timestamp of the last run.

# License

[MIT](https://github.com/otakup0pe/ansible-lvm/blob/master/LICENSE)

# Author

This Ansible role was created by [Jonathan Freedman](http://jonathanfreedman.bio/).
