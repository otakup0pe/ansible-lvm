[![Maintenance](https://img.shields.io/maintenance/yes/2016.svg)]()

Ansible / LVM Mashup
--------------------

I've had various incantations of this over the past few years for side projects, but here it is as something MIT licensed. You can use this Ansible role to create both LUKS encrypted and unencrypted logical volumes. The role will handle the creation of your volume group as well, if needed.

The role is entirely variable driven. You can simply include the role and pass in variables and it will handle the rest. The following example would setup two one gig logical volumes, with one being encrypted.

```
- role: lvm
  pv: "/dev/sdb"
  vg: "test-volume"
  lvm_encfs:
  - name: "foo"
    mnt: "/mnt/encrypted"
    size: "1G"
    vg: "test-volume"
    key: "key.txt"
  lvm_plain:
  - name: "bar"
    mnt: "/mnt/clear"
    size: "1G"
    vg: "test-volume"
```

# Note About Crypto

The LUKS key is intentionally _not_ stored on hosts. This implies running `ansible-playbook` on hosts after they have been brought back up. The thought is to move the key into a Hashicorp Vault instance and then pull it in with an Ansible lookup module. The key must be accessible on the executing workstation.

# Attributes

* `vg` is the name of the volume group.
* `pv` is a list of physical volumes to use for the volume group.
* `lvm_crypt_suffix` is the suffix to append to the intermediary encrypted volume.
* `lvm_key_source` dictates where to look for keys.
* `lvm_key_dest` dictates where to cache keys during runtime.

## `lvm_encfs` and `lvm_plain`

This is a list of YAML objects representing logical volumes. Each entry _must_ have the following items.

* `mnt` the location to mount the volume.
* `size` in a format that LVM can understand.
* `vg` is the volume group specified in 
* `name` a friendly name for the mountpoint

The `lvm_encfs` object _must_ also have a `key` value. Keys will receive a `.key` suffix and searched for under `lvm_key_source`.

# License

[MIT](https://github.com/otakup0pe/ansible-lvm/blob/master/LICENSE)

# Author

This Ansible role was created by [Jonathan Freedman](http://jonathanfreedman.bio/).
