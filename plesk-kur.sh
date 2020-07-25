#!/usr/bin/env bash

plesk_email='admin@ahmet.com'
plesk_pass='PleskUbuntu123'
plesk_name='admin'

plesk_ui=spv

fail2ban=yes

http2=yes

pci_compliance=false

clone=off

if [ "$(id -u)" != "0" ]; then
    echo ""
    echo "Root olmadan çalışmaz. sudo su yazarak root ol."
    exit 1
fi

if {
    plesk version >/dev/null 2>&1
}; then
    readonly plesk_installed="y"
else
    plesk_installed=""
fi

readonly plesk_linux_distro=$(lsb_release -is)
readonly plesk_distro_version=$(lsb_release -sc)
readonly plesk_distro_id=$(lsb_release -rs)
readonly plesk_srv_arch="$(uname -m)"
readonly plesk_kvm_detec=$(systemd-detect-virt)

echo ""
echo "Kuruluma hoşgeldin..."
echo ""

while [ "$#" -gt 0 ]; do
    case "$1" in
    --interactive)
        interactive_install="y"
        ;;
    --travis)
        travis="y"
        release_tiers="testing"
        agreement="true"
        mariadb_server_install="y"
        mariadb_version_install="10.3"
        ;;
    -n | --name)
        plesk_name="$2"
        shift
        ;;
    -p | --password)
        plesk_pass="$2"
        shift
        ;;
    --email)
        plesk_email="$2"
        shift
        ;;
    --testing)
        release_tiers="testing"
        ;;
    -r | --release)
        release_tiers="$2"
        shift
        ;;
    -y | --agreement)
        agreement="true"
        ;;
    -i | --license)
        activation_key="$2"
        shift
        ;;
    -m | --mariadb)
        mariadb_server_install="y"
        mariadb_version_install="$2"
        shift
        ;;
    *) ;;
    esac
    shift
done

sleep 1
if [ "$interactive_install" = "y" ]; then
    if [ ! -d /etc/mysql ]; then
        while [[ $mariadb_server_install != "y" && $mariadb_server_install != "n" ]]; do
            echo -e "MariaDB Kurulsun mu ? [y/n]: "
            read -r mariadb_server_install
        done
        if [[ "$mariadb_server_install" == "y" ]]; then
            while [[ $mariadb_version_install != "10.1" && $mariadb_version_install != "10.2" && $mariadb_version_install != "10.3" ]]; do
                echo -e "Hangi versiyon kurulsun ? [10.1 / 10.2 / 10.3]: "
                read -r mariadb_version_install
            done
        fi
        sleep 1
    fi
    if [ -z "$agreement" ]; then
        while [[ $agreement != "y" && $agreement != "n" ]]; do
            echo -e "Kuruluma başlansın mı ? [y/n]: "
            read -r agreement
            clear
            history -c
            echo "Kuruluma başlandı ortalama 10dk içinde kurulum bitmiş olacak."
        done
    fi

fi
if [ -z "$plesk_installed" ]; then
    if [ -z "$mariadb_server_install" ]; then
        mariadb_server_install="y"
    fi
    if [ -z "$mariadb_version_install" ]; then
        mariadb_version_install="10.3"
    fi
fi

if [[ -z "$plesk_email" || -z "$plesk_pass" || -z "$plesk_name" || -z "$agreement" ]]; then
    exit 1
fi

echo ""
sleep 5

export DEBIAN_FRONTEND=noninteractive

if [ -z "$travis" ]; then
    apt-get update -qq >> /dev/null 2>&1
    apt-get --option=Dpkg::options::=--force-confmiss \
        --option=Dpkg::options::=--force-confold \
        --option=Dpkg::options::=--force-unsafe-io \
        dist-upgrade --assume-yes --quiet >> /dev/null 2>&1
    apt-get autoremove --purge -qq >> /dev/null 2>&1
    apt-get autoclean -qq >> /dev/null 2>&1
fi

apt-get \
    --option=Dpkg::options::=--force-confmiss \
    --option=Dpkg::options::=--force-confold \
    --assume-yes install haveged curl git unzip zip htop \
    nload nmon ntp gnupg gnupg2 wget pigz tree tzdata ccze --quiet >> /dev/null 2>&1

if ! grep -q "time.cloudflare.com" /etc/systemd/timesyncd.conf; then
    sed -e 's/^#NTP=/NTP=time.cloudflare.com 0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org 2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org/' -i /etc/systemd/timesyncd.conf >> /dev/null 2>&1
    timedatectl set-ntp 1
fi

export HISTSIZE=10000

if [ ! -f /etc/sysctl.d/60-plesk-tweaks.conf ]; then
    if [ "$plesk_srv_arch" = "x86_64" ]; then
        wget -qO /etc/sysctl.d/60-plesk-tweaks.conf \
            https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/sysctl.mustache
        if [ "$plesk_distro_version" = "bionic" ] || [ "$plesk_distro_version" = "disco" ] || [ "$plesk_distro_version" = "buster" ]; then
            modprobe tcp_bbr && echo 'tcp_bbr' >>/etc/modules-load.d/bbr.conf
            echo -e '\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv4.tcp_notsent_lowat = 16384' >>/etc/sysctl.d/60-plesk-tweaks.conf
        else
            modprobe tcp_htcp && echo 'tcp_htcp' >>/etc/modules-load.d/htcp.conf
            echo 'net.ipv4.tcp_congestion_control = htcp' >>/etc/sysctl.d/60-plesk-tweaks.conf
        fi
        sysctl -eq -p /etc/sysctl.d/60-plesk-tweaks.conf
    fi
fi

if [ ! -x /opt/kernel-tweak.sh ]; then
    {
        wget -qO /opt/kernel-tweak.sh https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/kernel-tweak.sh
        chmod +x /opt/kernel-tweak.sh
        wget -qO /lib/systemd/system/kernel-tweak.service https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/kernel-tweak.service
        systemctl enable kernel-tweak.service
        systemctl start kernel-tweak.service
    } >>/tmp/plesk-install.log 2>&1
fi

if [ "$mariadb_server_install" = "y" ]; then
    {
        wget -qO mariadb_repo_setup https://downloads.mariadb.com/MariaDB/mariadb_repo_setup >> /dev/null 2>&1
        chmod +x mariadb_repo_setup >> /dev/null 2>&1
        ./mariadb_repo_setup --mariadb-server-version=$mariadb_version_install --skip-maxscale -y >> /dev/null 2>&1
        rm mariadb_repo_setup >> /dev/null 2>&1
        apt-get update -qq >> /dev/null 2>&1
    } >>/tmp/plesk-install.log 2>&1
fi

if [ "$mariadb_server_install" = "y" ]; then
    if [ ! -d /etc/mysql ]; then
        MYSQL_ROOT_PASS="" >> /dev/null 2>&1
        echo "mariadb-server-${mariadb_version_install} mysql-server/root_password password ${MYSQL_ROOT_PASS}" | debconf-set-selections >> /dev/null 2>&1
        echo "mariadb-server-${mariadb_version_install} mysql-server/root_password_again password ${MYSQL_ROOT_PASS}" | debconf-set-selections >> /dev/null 2>&1
        apt-get install -qq mariadb-server >> /dev/null 2>&1
        mysql -e "DROP USER ''@'localhost'" >/dev/null 2>&1
        mysql -e "DROP USER ''@'$(hostname)'" >/dev/null 2>&1
        mysql -e "DROP DATABASE test" >/dev/null 2>&1
        mysql -e "FLUSH PRIVILEGES" >> /dev/null 2>&1
    fi
fi

if [ "$mariadb_server_install" = "y" ]; then
    cp /etc/mysql/my.cnf /etc/mysql/my.cnf.bak >> /dev/null 2>&1
    wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/my.cnf -O /etc/mysql/my.cnf >> /dev/null 2>&1
    service mysql stop >> /dev/null 2>&1
    mv /var/lib/mysql/ib_logfile0 /var/lib/mysql/ib_logfile0.bak >> /dev/null 2>&1
    mv /var/lib/mysql/ib_logfile1 /var/lib/mysql/ib_logfile1.bak >> /dev/null 2>&1
    echo -e '[Service]\nLimitNOFILE=500000' >/etc/systemd/system/mariadb.service.d/limits.conf >> /dev/null 2>&1
    systemctl daemon-reload >> /dev/null 2>&1 
    service mysql start >> /dev/null 2>&1

fi

if [ -z "$plesk_installed" ]; then
    wget -O plesk-installer https://installer.plesk.com/plesk-installer >> /dev/null 2>&1
    echo >> /dev/null 2>&1

    chmod +x ./plesk-installer >> /dev/null 2>&1
    echo >> /dev/null 2>&1

    if ! { ./plesk-installer install release --components panel fail2ban modsecurity \
        l10n pmm mysqlgroup repair-kit \
        roundcube spamassassin postfix dovecot \
        proftpd awstats mod_fcgid webservers \
        nginx php7.3 php7.4 config-troubleshooter \
        psa-firewall wp-toolkit letsencrypt \
        imunifyav sslit; } >>/tmp/plesk-install.log 2>&1 >> /dev/null 2>&1; then
        echo
        echo "An error occurred! The installation of Plesk failed. Please see logged lines above for error handling!" >> /dev/null 2>&1
        tail -f 50 /tmp/plesk-install.log | ccze -A >> /dev/null 2>&1
        exit 1 
    fi

    if [ "$plesk_kvm_detec" = "kvm" ]; then
        echo "Enable VPS Optimized Mode" >> /dev/null 2>&1
        plesk bin vps_optimized --turn-on >>/tmp/plesk-install.log 2>&1 >> /dev/null 2>&1 
        echo
    fi

    export PSA_PASSWORD=$plesk_pass

    if [ -n "$activation_key" ]; then
        echo "Starting initialization process of your Plesk server" >> /dev/null 2>&1
        /usr/sbin/plesk bin init_conf --init -email "$plesk_email" -passwd "" -name "$plesk_name" -license_agreed "$agreement" >> /dev/null 2>&1
        echo "Installing Plesk Activation Code" >> /dev/null 2>&1
        /usr/sbin/plesk bin license --install "$activation_key" >> /dev/null 2>&1
        echo
    else
        echo "Starting initialization process of your Plesk server" >> /dev/null 2>&1
        /usr/sbin/plesk bin init_conf --init -email "$plesk_email" -passwd "" -name "$plesk_name" -license_agreed "$agreement" -trial_license true >> /dev/null 2>&1
    fi

    if [ "$plesk_ui" = "spv" ]; then
        echo "Setting to Service Provider View" >> /dev/null 2>&1
        /usr/sbin/plesk bin poweruser --off >> /dev/null 2>&1
        echo
    else
        echo "Setting to Power user View" >> /dev/null 2>&1
        /usr/sbin/plesk bin poweruser --on >> /dev/null 2>&1
        echo
    fi

    {
        iptables -I INPUT -p tcp --dport 21 -j ACCEPT
        iptables -I INPUT -p tcp --dport 22 -j ACCEPT
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
        iptables -I INPUT -p tcp --dport 443 -j ACCEPT
        iptables -I INPUT -p tcp --dport 465 -j ACCEPT
        iptables -I INPUT -p tcp --dport 993 -j ACCEPT
        iptables -I INPUT -p tcp --dport 995 -j ACCEPT
        iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
        iptables -I INPUT -p tcp --dport 8447 -j ACCEPT
        iptables -I INPUT -p tcp --dport 8880 -j ACCEPT
    } >>/tmp/plesk-install.log 2>&1

    echo
fi




if [ "$fail2ban" = "yes" ]; then
    echo "Configuring Fail2Ban and its Jails" >> /dev/null 2>&1
    /usr/sbin/plesk bin ip_ban --enable
    /usr/sbin/plesk bin ip_ban --enable-jails ssh
    /usr/sbin/plesk bin ip_ban --enable-jails recidive
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-proftpd
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-postfix
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-dovecot
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-roundcube
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-apache-badbot
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-panel
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-wordpress
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-apache
    echo
fi

if [ "$http2" = "yes" ]; then
    echo "Activating http2" >> /dev/null 2>&1
    /usr/sbin/plesk bin http2_pref --enable >> /dev/null 2>&1
    echo
fi

if [ "$pci_compliance" = "yes" ]; then >> /dev/null 2>&1
    /usr/sbin/plesk sbin pci_compliance_resolver --enable all >> /dev/null 2>&1
fi

echo "Installing Requested Plesk Extensions" >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing SEO Toolkit" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/2ae9cd0b-bc5c-4464-a12d-bd882c651392-xovi/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing Revisium Antivirus for Websites" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/b71916cf-614e-4b11-9644-a5fe82060aaf-revisium-antivirus/download >> /dev/null 2>&1
echo "" >> /dev/null 2>&1
clear
echo "Installing Plesk Migration Manager" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/bebc4866-d171-45fb-91a6-4b139b8c9a1b-panel-migrator/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing Code Editor" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/e789f164-5896-4544-ab72-594632bcea01-rich-editor/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing MagicSpam" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/b49f9b1b-e8cf-41e1-bd59-4509d92891f7-magicspam/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing Panel.ini Extension" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/05bdda39-792b-441c-9e93-76a6ab89c85a-panel-ini-editor/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Installing Schedule Backup list Extension" >> /dev/null 2>&1
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/17ffcf2a-8e8f-4cb2-9265-1543ff530984-scheduled-backups-list/download >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
echo "Set custom panel.ini config" >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/panel.ini -O /usr/local/psa/admin/conf/panel.ini >> /dev/null 2>&1
echo >> /dev/null 2>&1
clear
plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set crs -waf-rule-set-update-period daily -waf-config-preset tradeoff >> /dev/null 2>&1
echo >> /dev/null 2>&1

rm -rf /root/parallels >> /dev/null 2>&1
rm -rf /root/plesk-installer >> /dev/null 2>&1
rm -rf /root/ubuntu-nginx-web-server >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/server.php -O /opt/psa/admin/conf/templates/default/server.php >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/nginxDomainVirtualHost.php -O /opt/psa/admin/conf/templates/default/domain/nginxDomainVirtualHost.php >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/nginxForwarding.php -O /opt/psa/admin/conf/templates/default/domain/nginxForwarding.php >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/domainVirtualHost.php -O /opt/psa/admin/conf/templates/default/domain/domainVirtualHost.php >> /dev/null 2>&1
/usr/local/psa/admin/sbin/httpdmng --reconfigure-all >> /dev/null 2>&1
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/sshd_config -O /etc/ssh/sshd_config >> /dev/null 2>&1
sshd -t >> /dev/null 2>&1
service sshd restart >> /dev/null 2>&1
apt-get install redis -y >> /dev/null 2>&1




echo
echo "Plesk Panel Kuruldu"
echo

if [ "$clone" = "on" ]; then
    /usr/sbin/plesk bin cloning --update -prepare-public-image true -reset-license true -skip-update true >> /dev/null 2>&1
else
    echo "Giriş Bilgileri" >> /dev/null 2>&1
    /usr/sbin/plesk login 
fi

echo
echo "İşlemlere devam edebilirsiniz."
echo "SSH Portunuz 1453 Oldu."
echo "Plesk İnce ayarları yapıldı, nginx/apache loglama kapatıldı ve powered by plesk kaldırıldı."
echo

