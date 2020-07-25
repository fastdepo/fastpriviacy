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
			bash <(wget -O - https://git.io/JJBTr 2> /dev/null;)
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
			wget https://git.io/JJBkb 2> /dev/null;
			wget https://git.io/JJBkN 2> /dev/null;
			wget https://git.io/JJBkA 2> /dev/null;
			sysctl -e -p /etc/security/limits.conf 2> /dev/null;
			modprobe tcp_bbr && echo 'tcp_bbr' >> /etc/modules-load.d/bbr.conf 2> /dev/null;
			echo -e '\nnet.ipv4.tcp_congestion_control = bbr\nnet.ipv4.tcp_notsent_lowat = 16384' >> /etc/sysctl.d/999-perf.conf 2> /dev/null;
			echo never > /sys/kernel/mm/transparent_hugepage/enabled 2> /dev/null;
			echo "Performans ayarları yapıldı."

            ;;
        4)
            echo "Kernel Versiyonu Güncellemeyi seçiniz."
			bash <(wget -O - https://git.io/JJ4zi 2> /dev/null;) -i --yes 2> /dev/null
			clear
			history -c
			reboot
            ;;				
esac
