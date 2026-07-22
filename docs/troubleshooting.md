# Troubleshooting

Run the built-in health check first — it covers the most common failure points:

```bash
sudo bash scripts/health_check.sh
```

## Installation issues

**`apt-get` fails with a lock error**
Another process (unattended-upgrades, a previous run of `install.sh`) holds the dpkg lock. `common.sh`'s `wait_for_apt_lock` already retries for up to 5 minutes; if it still fails, check:
```bash
sudo lsof /var/lib/dpkg/lock-frontend
```

**Zabbix repository package fails to download**
`install_zabbix.sh` builds the repo package URL based on your detected Ubuntu version. If Zabbix has not yet published a package for a brand-new Ubuntu point release, check <https://repo.zabbix.com/zabbix/> manually and adjust `ZABBIX_VERSION` in `config/.env` if needed.

**Grafana pinned version not found**
`install_grafana.sh` automatically falls back to the latest available `grafana` package if the exact pinned version (`GRAFANA_VERSION`) isn't in the repository yet.

## Service issues

**Zabbix server won't start**
```bash
sudo journalctl -u zabbix-server -n 50
sudo tail -n 50 /var/log/zabbix/zabbix_server.log
```
Common causes: wrong database credentials in `/etc/zabbix/zabbix_server.conf`, or the schema wasn't imported (re-run `sudo bash scripts/install_database.sh`).

**Grafana won't start / plugin not loading**
```bash
sudo journalctl -u grafana-server -n 50
```
Check that the plugin ID is listed under `allow_loading_unsigned_plugins` in `/etc/grafana/grafana.ini`, then:
```bash
sudo grafana-cli plugins ls
sudo systemctl restart grafana-server
```

**Nginx returns 502 Bad Gateway on the Zabbix frontend**
This usually means PHP-FPM isn't running or the socket path in the Nginx config doesn't match reality:
```bash
sudo systemctl status php*-fpm
sudo find /run/php -name '*.sock'
```
Update the `fastcgi_pass` line in `/etc/nginx/sites-available/zabbix-monitoring.conf` if the socket path differs, then `sudo systemctl restart nginx`.

## SNMP issues

**No data from an SNMP device**
1. Test manually from the monitoring server:
   ```bash
   snmpget -v2c -c <community> <device-ip> 1.3.6.1.2.1.1.1.0
   ```
2. If this times out: check firewall rules on the device/network path allow UDP/161 from the monitoring server's IP.
3. If it returns "No response": verify the community string / SNMPv3 credentials match exactly what's configured on the device.
4. If it works via CLI but not in Zabbix: re-check the SNMP interface configuration on the host object (IP, port, version, community/security name) in **Data collection > Hosts**.

**Interface discovery finds no interfaces**
Some devices restrict SNMP walks on `IF-MIB` unless the community string has sufficient read access, or expose interfaces only under vendor-proprietary MIBs outside the scope of `generic-snmp-device.yaml`. Use `snmpwalk` to confirm the standard OIDs are present:
```bash
snmpwalk -v2c -c <community> <device-ip> 1.3.6.1.2.1.2.2.1.2
```

## Database issues

**"Access denied" errors connecting to MariaDB**
Confirm the credentials in `config/.env` match what's in the database:
```bash
mysql -u<DB_USER> -p<DB_PASSWORD> -e "SELECT 1;" <DB_NAME>
```
If they don't match, either update `config/.env` to reflect the real password, or reset it:
```bash
sudo mysql -uroot -p<DB_ROOT_PASSWORD> -e "ALTER USER '<DB_USER>'@'localhost' IDENTIFIED BY 'NEW_PASSWORD'; FLUSH PRIVILEGES;"
```
then update `config/.env` and restart `zabbix-server`.

## Firewall issues

**Cannot reach Grafana/Zabbix from another machine after install**
Check UFW status:
```bash
sudo ufw status verbose
```
`configure_firewall.sh` opens the ports defined in `config/.env` (`WEB_LISTEN_PORT`, `GRAFANA_PORT`, `ZABBIX_SERVER_PORT`, `ZABBIX_AGENT_PORT`) plus SSH. If you changed any port after install, re-run:
```bash
sudo bash scripts/configure_firewall.sh
```

## Still stuck?

Check the installer logs in `logs/install-YYYYMMDD.log` for the exact command and error output from the failing step.
