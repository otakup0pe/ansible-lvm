[![Maintenance](https://img.shields.io/maintenance/yes/2026.svg)]()

# otakup0pe.lvm

An Ansible role for creating volume groups and encrypted or unencrypted logical
volumes.

## Requirements

The controller needs the `community.general`, `community.crypto`, and
`ansible.posix` collections. Managed hosts need `lvm2`, `cryptsetup`,
`util-linux`, and `e2fsprogs`; this role does not install them.

## Usage

```yaml
- role: otakup0pe.lvm
  pv: /dev/sdb
  vg: test-volume
  lvm_plain:
    - mnt: clear
      size: "1"
  lvm_encfs:
    - mnt: encrypted
      size: "1"
      key: key
```

This creates one-gigabyte volumes mounted at `/mnt/clear` and
`/mnt/encrypted`.

## Variables

- `vg`: volume group name.
- `pv`: physical volume or volumes used to create the group. Omit it for an
  existing group.
- `lvm_plain`: unencrypted logical volumes.
- `lvm_encfs`: LUKS-encrypted logical volumes.
- `lvm_default_mnt_prefix`: default mount root; `/mnt`.
- `lvm_crypt_suffix`: encrypted backing-volume suffix; `crypto`.
- `lvm_key_source`: controller directory containing encryption keys.
- `lvm_key_dest`: temporary key staging directory on the managed host.
- `lvm_key_dest_mode`: staging directory mode; `0400`.

Each volume requires:

- `mnt`: volume name and mount-point basename.
- `size`: whole gigabytes, without a unit.
- `key`: encryption key name; required only for `lvm_encfs`. The source file
  is `<key>.key`.

Optional per-volume fields:

- `mnt_prefix`: overrides `lvm_default_mnt_prefix`.
- `boot`: mounts at boot. Defaults to `true` for encrypted volumes and
  `false` for plain volumes.
- `mount_opts`: filesystem mount options.
- `mount_state`: `mounted` by default; use `present` when another service
  owns activation.

Keys are staged only while an encrypted volume is opened or resized, then
removed even if the task fails. After a reboot, encrypted volumes normally need
another playbook run unless another service opens them.

## Prometheus metrics

Set `lvm_metrics_enabled: true` to install the timer-driven node_exporter
textfile collector. `lvm_metrics_textfile_dir` must already exist; this role
never creates or modifies it.

Each role invocation writes an expectation fragment for its volume group.
Fragments accumulate in `lvm_metrics_expectations_dir`, allowing one collector
to cover volume groups managed by separate invocations.

The collector exports volume-group free and total bytes, expected volume-group,
logical-volume, and mapper presence, scrape success, and last-run timestamp.

## License

MIT. Created by [Jonathan Freedman](http://jonathanfreedman.bio/).
