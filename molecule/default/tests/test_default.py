def test_volume_group_and_logical_volumes(host):
    result = host.run("lvs --noheadings --options lv_name molecule_vg")
    assert result.rc == 0
    assert set(result.stdout.split()) == {"plain", "encrypted-crypto"}


def test_filesystems_are_mounted(host):
    for path in ("/srv/plain", "/srv/encrypted"):
        result = host.run("findmnt --noheadings --output FSTYPE --mountpoint %s", path)
        assert result.rc == 0
        assert result.stdout.strip() == "ext4"


def test_encrypted_volume_is_open_without_staged_key(host):
    assert host.run("test -b /dev/mapper/encrypted").rc == 0
    assert host.run("cryptsetup status encrypted").rc == 0
    assert not host.file("/var/cache/ansible-lvm/molecule").exists


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
