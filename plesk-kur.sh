#!/usr/bin/env bash

plesk_email='admin@ahmet.host'
plesk_pass='PleskAhmet123'
plesk_name='admin'
plesk_ui=spv
fail2ban=yes
http2=yes
pci_compliance=false
clone=off

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

while [ "$#" -gt 0 ]; do
    case "$1" in
    --hizlikur)
        hizli_kur="y"
        ;;
    --travis-secmeli)
        travis-secmeli="y"
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
if [ "$hizli_kur" = "y" ]; then
    if [ ! -d /etc/mysql ]; then
        while [[ $mariadb_server_install != "y" && $mariadb_server_install != "n" ]]; do
            echo -e "MariaDB Kurulsun mu ? [y/n]: "
            read -r mariadb_server_install
        done
        if [[ "$mariadb_server_install" == "y" ]]; then
            while [[ $mariadb_version_install != "10.1" && $mariadb_version_install != "10.2" && $mariadb_version_install != "10.3" ]]; do
                echo -e "Versiyon [10.1 / 10.2 / 10.3] kurulsun. Örnek 10.3 : "
                read -r mariadb_version_install
            done
        fi
        sleep 1
    fi
    if [ -z "$agreement" ]; then
        while [[ $agreement != "y" && $agreement != "n" ]]; do
            echo -e "Kuruluma başlıyorum? [y/n]: "
            read -r agreement
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
    echo 'One or more variables are undefined. Please check your initialization values.'
    exit 1
fi

sleep 5

export DEBIAN_FRONTEND=noninteractive

if [ -z "$travis-secmeli" ]; then
    apt-get update -qq
    apt-get --option=Dpkg::options::=--force-confmiss \
        --option=Dpkg::options::=--force-confold \
        --option=Dpkg::options::=--force-unsafe-io \
        dist-upgrade --assume-yes --quiet
    apt-get autoremove --purge -qq
    apt-get autoclean -qq
fi

apt-get \
    --option=Dpkg::options::=--force-confmiss \
    --option=Dpkg::options::=--force-confold \
    --assume-yes install haveged curl git unzip zip htop \
    nload nmon ntp gnupg gnupg2 wget pigz tree tzdata ccze --quiet

if ! grep -q "time.cloudflare.com" /etc/systemd/timesyncd.conf; then
    sed -e 's/^#NTP=/NTP=time.cloudflare.com 0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org 2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org/' -i /etc/systemd/timesyncd.conf
    timedatectl set-ntp 1
fi

export HISTSIZE=10000

if [ ! -f /etc/sysctl.d/60-plesk-tweaks.conf ]; then
    if [ "$plesk_srv_arch" = "x86_64" ]; then
        wget -qO /etc/sysctl.d/60-plesk-tweaks.conf \
            https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/sysctl.mustache 2> /dev/null
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
        wget -qO /opt/kernel-tweak.sh https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/kernel-tweak.sh 2> /dev/null
        chmod +x /opt/kernel-tweak.sh
        wget -qO /lib/systemd/system/kernel-tweak.service https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/kernel-tweak.service 2> /dev/null
        systemctl enable kernel-tweak.service
        systemctl start kernel-tweak.service
    } >>/tmp/plesk-install.log 2>&1
fi

NET_INTERFACES_WAN=$(ip -4 route get 8.8.8.8 | grep -oP "dev [^[:space:]]+ " | cut -d ' ' -f 2)
{
    echo ""
    echo "# do not autoconfigure IPv6 on $NET_INTERFACES_WAN"
    echo "net.ipv6.conf.$NET_INTERFACES_WAN.autoconf = 0"
    echo "net.ipv6.conf.$NET_INTERFACES_WAN.accept_ra = 0"
    echo "net.ipv6.conf.$NET_INTERFACES_WAN.accept_ra = 0"
    echo "net.ipv6.conf.$NET_INTERFACES_WAN.autoconf = 0"
    echo "net.ipv6.conf.$NET_INTERFACES_WAN.accept_ra_defrtr = 0"
} >>/etc/sysctl.d/60-plesk-tweaks.conf


if [ "$mariadb_server_install" = "y" ]; then
    {
        wget -qO mariadb_repo_setup https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
        chmod +x mariadb_repo_setup
        ./mariadb_repo_setup --mariadb-server-version=$mariadb_version_install --skip-maxscale -y
        rm mariadb_repo_setup
        apt-get update -qq
    } >>/tmp/plesk-install.log 2>&1
fi

if [ "$mariadb_server_install" = "y" ]; then
    if [ ! -d /etc/mysql ]; then

        MYSQL_ROOT_PASS=""
        echo "mariadb-server-${mariadb_version_install} mysql-server/root_password password ${MYSQL_ROOT_PASS}" | debconf-set-selections
        echo "mariadb-server-${mariadb_version_install} mysql-server/root_password_again password ${MYSQL_ROOT_PASS}" | debconf-set-selections
        apt-get install -qq mariadb-server # -qq implies -y --force-yes
        mysql -e "DROP USER ''@'localhost'" >/dev/null 2>&1
        mysql -e "DROP USER ''@'$(hostname)'" >/dev/null 2>&1
        mysql -e "DROP DATABASE test" >/dev/null 2>&1
        mysql -e "FLUSH PRIVILEGES"
    fi
fi

if [ "$mariadb_server_install" = "y" ]; then

    cp /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
	wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/my.cnf -O /etc/mysql/my.cnf 2> /dev/null
    service mysql stop
    mv /var/lib/mysql/ib_logfile0 /var/lib/mysql/ib_logfile0.bak
    mv /var/lib/mysql/ib_logfile1 /var/lib/mysql/ib_logfile1.bak
    echo -e '[Service]\nLimitNOFILE=500000' >/etc/systemd/system/mariadb.service.d/limits.conf
    systemctl daemon-reload
    service mysql start

fi

if [ -z "$plesk_installed" ]; then
    wget -O plesk-installer https://installer.plesk.com/plesk-installer
    echo
    chmod +x ./plesk-installer
    echo

    if ! { ./plesk-installer install release --components panel fail2ban modsecurity \
        l10n pmm mysqlgroup repair-kit \
        spamassassin postfix dovecot \
        proftpd awstats mod_fcgid webservers \
        nginx php7.4 php7.3 config-troubleshooter \
        psa-firewall wp-toolkit letsencrypt \
        imunifyav sslit; } >>/tmp/plesk-install.log 2>&1; then
        echo
        echo "An error occurred! The installation of Plesk failed. Please see logged lines above for error handling!"
        tail -f 50 /tmp/plesk-install.log | ccze -A
        exit 1
    fi

    if [ "$plesk_kvm_detec" = "kvm" ]; then

        echo "Enable VPS Optimized Mode"
        plesk bin vps_optimized --turn-on >>/tmp/plesk-install.log 2>&1
        echo
    fi

    export PSA_PASSWORD=$plesk_pass

    if [ -n "$activation_key" ]; then
        /usr/sbin/plesk bin init_conf --init -email "$plesk_email" -passwd "" -name "$plesk_name" -license_agreed "$agreement"
        /usr/sbin/plesk bin license --install "$activation_key"
        echo
    else
        /usr/sbin/plesk bin init_conf --init -email "$plesk_email" -passwd "" -name "$plesk_name" -license_agreed "$agreement" -trial_license true
    fi


    if [ "$plesk_ui" = "spv" ]; then
        /usr/sbin/plesk bin poweruser --off
        echo
    else
        /usr/sbin/plesk bin poweruser --on
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

    plesk bin server_pref --update-web-app-firewall -waf-rule-engine on -waf-rule-set crs -waf-rule-set-update-period daily -waf-config-preset tradeoff
	plesk bin locales --set-default tr-TR		
	echo
fi



if [ "$fail2ban" = "yes" ]; then
    echo "Configuring Fail2Ban and its Jails"
    /usr/sbin/plesk bin ip_ban --enable
    /usr/sbin/plesk bin ip_ban --enable-jails ssh
    /usr/sbin/plesk bin ip_ban --enable-jails recidive
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-proftpd
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-postfix
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-dovecot
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-modsecurity
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-roundcube
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-apache-badbot
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-panel
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-wordpress
    /usr/sbin/plesk bin ip_ban --enable-jails plesk-apache
    echo
fi

if [ "$http2" = "yes" ]; then
    echo "Activating http2"
    /usr/sbin/plesk bin http2_pref --enable
    echo
fi

if [ "$pci_compliance" = "yes" ]; then
    /usr/sbin/plesk sbin pci_compliance_resolver --enable all
fi

echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/2ae9cd0b-bc5c-4464-a12d-bd882c651392-xovi/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/b71916cf-614e-4b11-9644-a5fe82060aaf-revisium-antivirus/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/bebc4866-d171-45fb-91a6-4b139b8c9a1b-panel-migrator/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/e789f164-5896-4544-ab72-594632bcea01-rich-editor/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/b49f9b1b-e8cf-41e1-bd59-4509d92891f7-magicspam/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/05bdda39-792b-441c-9e93-76a6ab89c85a-panel-ini-editor/download
echo
/usr/sbin/plesk bin extension --install-url https://ext.plesk.com/packages/17ffcf2a-8e8f-4cb2-9265-1543ff530984-scheduled-backups-list/download
echo
wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/panel.ini -O /usr/local/psa/admin/conf/panel.ini 2> /dev/null
echo

if [ "$clone" = "on" ]; then
    /usr/sbin/plesk bin cloning --update -prepare-public-image true -reset-license true -skip-update true
else
    /usr/sbin/plesk login
fi

echo
echo "Kurulum Başarılı"
echo
