def _fstab_options(host, mountpoint):
    """Return the fstab options field for a mount point, or None."""
    for line in host.file("/etc/fstab").content_string.splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] == mountpoint:
            return fields[3].split(",")
    return None


def test_volume_group_and_logical_volumes(host):
    result = host.run("lvs --noheadings --options lv_name molecule_vg")
    assert result.rc == 0
    assert set(result.stdout.split()) == {
        "plain",
        "plainboot",
        "encrypted-crypto",
    }


def test_filesystems_are_mounted(host):
    for path in ("/srv/plainboot", "/srv/encrypted"):
        result = host.run("findmnt --noheadings --output FSTYPE --mountpoint %s", path)
        assert result.rc == 0
        assert result.stdout.strip() == "ext4"


def test_present_volume_is_recorded_but_not_mounted(host):
    assert _fstab_options(host, "/srv/plain") is not None
    result = host.run(
        "findmnt --noheadings --output FSTYPE --mountpoint %s", "/srv/plain"
    )
    assert result.rc != 0


def test_encrypted_volume_is_open_without_staged_key(host):
    assert host.run("test -b /dev/mapper/encrypted").rc == 0
    assert host.run("cryptsetup status encrypted").rc == 0
    assert not host.file("/var/cache/ansible-lvm/molecule").exists


def test_encrypted_volume_can_be_excluded_from_local_filesystems(host):
    result = host.run("systemctl show --property=Before --value srv-encrypted.mount")
    assert result.rc == 0
    assert "local-fs.target" not in set(result.stdout.split())


def test_plain_volume_boot_and_mount_opts_are_honoured(host):
    runtime = _fstab_options(host, "/srv/plain")
    assert runtime.count("noauto") == 1
    assert runtime.count("nofail") == 1
    assert "auto" not in runtime

    booted = _fstab_options(host, "/srv/plainboot")
    assert "noauto" not in booted
    assert "nofail" in booted


def test_externally_managed_metrics_directory_is_unchanged(host):
    directory = host.file("/var/lib/node_exporter/textfile_collector")
    assert directory.is_directory
    assert directory.mode == 0o2775


def test_metrics_timer_and_output(host):
    assert host.run("systemctl is-enabled lvm-vg-metrics.timer").stdout.strip() == "enabled"
    assert host.run("systemctl is-active lvm-vg-metrics.timer").stdout.strip() == "active"
    assert host.run("systemctl start lvm-vg-metrics.service").rc == 0

    metrics = host.file("/var/lib/node_exporter/textfile_collector/lvm_vg.prom")
    assert metrics.exists
    assert 'lvm_expected_vg_present{vg="molecule_vg"} 1' in metrics.content_string
    assert (
        'lvm_expected_mapper_present{vg="molecule_vg",'
        'lv="encrypted-crypto",mapper="encrypted"} 1'
        in metrics.content_string
    )
    assert "lvm_metrics_scrape_success 1" in metrics.content_string
