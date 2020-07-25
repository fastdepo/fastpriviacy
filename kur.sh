#!/bin/bash

HEIGHT=10
WIDTH=60
CHOICE_HEIGHT=20
BACKTITLE="Hızlı Kurulum v1.2"
TITLE="Hosgeldiniz"
MENU="Yapmak istediğiniz işlemi seçiniz.:"

OPTIONS=(1 "Plesk Kur"
         2 "Nginx Build Et"
         3 "Kernel Versiyonu Güncelle")

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
            echo "Hızlı Plesk Kurulumunu Seçtiniz."
			bash <(wget -O - https://git.io/JJ4za 2> /dev/null;) --interactive 
			clear
			history -c
            ;;
        2)
            echo "Nginx Build Seçtiniz."
			bash <(wget -O - https://git.io/JJ4zK 2> /dev/null;) --latest --dnyamic --pagespeed -openssl-system
			clear
			history -c
            ;;
        3)
            echo "Kernel Versiyonu Güncellemeyi seçiniz."
			bash <(wget -O - https://git.io/JJ4zi 2> /dev/null;) -i --yes 2> /dev/null
			clear
			history -c
			reboot
            ;;			
esac