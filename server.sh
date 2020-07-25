#!/bin/bash

HEIGHT=10
WIDTH=60
CHOICE_HEIGHT=20
BACKTITLE="Hızlı Kurulum v1.2"
TITLE="Hosgeldiniz"
MENU="Yapmak istediğiniz işlemi seçiniz.:"

OPTIONS=(1 "Depolama Server Kur"
         2 "Cache Server Kur"
         3 "Cache Server Performans Ayarlarını Yap"
         4 "Kernel Versiyonu Güncelle")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            echo "Depolama Server Kurmayı seçtiniz."
			bash <(wget -O - https://git.io/JJBTr 2> /dev/null;) --interactive 
			clear
			history -c
            ;;
        2)
            echo "Cache Server Kurmayı seçtiniz.."
			bash <(wget -O - https://git.io/JJBTV 2> /dev/null;)
			clear
			history -c
            ;;
        3)
            echo "Performans Ayarlarını Yapmayı seçtiniz."
			wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/999-perf.conf -O /etc/sysctl.d/999-perf.conf
			wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/limits.conf -O /etc/security/limits.conf
			https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/limits.conf -O /etc/systemd/system.conf
			sysctl -e -p /etc/security/limits.conf
			modprobe tcp_bbr && echo 'tcp_bbr' >> /etc/modules-load.d/bbr.conf
			echo -e '\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv4.tcp_notsent_lowat = 16384' >> /etc/sysctl.d/999-perf.conf
			echo never > /sys/kernel/mm/transparent_hugepage/enabled

            ;;
        4)
            echo "Kernel Versiyonu Güncellemeyi seçiniz."
			bash <(wget -O - https://git.io/JJ4zi 2> /dev/null;) -i --yes 2> /dev/null
			clear
			history -c
			reboot
            ;;				
esac
