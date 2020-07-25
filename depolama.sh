#!/bin/bash

NGINX_MAINLINE_VER=1.19.1
NGINX_STABLE_VER=1.18.0
LIBRESSL_VER=3.1.2
OPENSSL_VER=1.1.1g
NPS_VER=1.13.35.2
HEADERMOD_VER=0.33
LIBMAXMINDDB_VER=1.3.2
GEOIP2_VER=3.3
LUA_JIT_VER=2.1-20181029
LUA_NGINX_VER=0.10.16rc5
NGINX_DEV_KIT=0.3.1

if [[ $HEADLESS == "y" ]]; then
	OPTION=${OPTION:-1}
	NGINX_VER=${NGINX_VER:-1}
	PAGESPEED=${PAGESPEED:-n}
	BROTLI=${BROTLI:-n}
	HEADERMOD=${HEADERMOD:-n}
	GEOIP=${GEOIP:-n}
	FANCYINDEX=${FANCYINDEX:-n}
	CACHEPURGE=${CACHEPURGE:-n}
	LUA=${LUA:-n}
	WEBDAV=${WEBDAV:-n}
	VTS=${VTS:-n}
	TESTCOOKIE=${TESTCOOKIE:-n}
	HTTP3=${HTTP3:-n}
	MODSEC=${MODSEC:-n}
	SSL=${SSL:-1}
	RM_CONF=${RM_CONF:-y}
	RM_LOGS=${RM_LOGS:-y}
fi

if [[ $HEADLESS == "n" ]]; then
	clear
fi

if [[ $HEADLESS != "y" ]]; then
	echo ""
	echo "Ne vereyim abime ?"
	echo ""
	echo "   1) Nginx Kurulum - DEPOLAMA"
	echo "   2) Çıkış Yap "
	echo ""
	while [[ $OPTION != "1" && $OPTION != "2" ]]; do
		read -rp "Neyi seçiyorsun [1-2]: " OPTION
	done
fi

case $OPTION in
1)
	if [[ $HEADLESS != "y" ]]; then
		echo "Nginx hangi versiyonu kuralım?"
		echo "   1) Stabil $NGINX_STABLE_VER"
		echo "   2) Güncel $NGINX_MAINLINE_VER"
		echo ""
		while [[ $NGINX_VER != "1" && $NGINX_VER != "2" ]]; do
			read -rp "Neyi seçiyorsun [1-2]: " NGINX_VER
		done
	fi
	case $NGINX_VER in
	1)
		NGINX_VER=$NGINX_STABLE_VER
		;;
	2)
		NGINX_VER=$NGINX_MAINLINE_VER
		;;
	*)
		NGINX_VER=$NGINX_STABLE_VER
		;;
	esac
	if [[ $HEADLESS != "y" ]]; then
		echo "Modül Kuralım :"
		while [[ $BROTLI != "y" && $BROTLI != "n" ]]; do
			read -rp "       Brotli [y/n]: " -e BROTLI
		done
		while [[ $HEADERMOD != "y" && $HEADERMOD != "n" ]]; do
			read -rp "       Headers More $HEADERMOD_VER [y/n]: " -e HEADERMOD
		done
		while [[ $CACHEPURGE != "y" && $CACHEPURGE != "n" ]]; do
			read -rp "       ngx_cache_purge [y/n]: " -e CACHEPURGE
		done
		while [[ $VTS != "y" && $VTS != "n" ]]; do
			read -rp "       nginx VTS [y/n]: " -e VTS
		done
	fi

	if [[ $HEADLESS != "y" ]]; then
		echo ""
		clear
		read -n1 -r -p "Bilgileri topladım kuruluma hazırız. Kurulum için bir tuşa bas..."
		echo ""
	fi

	rm -r /usr/local/src/nginx/
	mkdir -p /usr/local/src/nginx/modules
	
	apt-get update
	apt-get install -y build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake

	#Brotli
	if [[ $BROTLI == 'y' ]]; then
		cd /usr/local/src/nginx/modules || exit 1
		git clone --depth 1 https://github.com/eustas/ngx_brotli
		cd ngx_brotli || exit 1
		git checkout v0.1.2
		git submodule update --init
	fi

	# More Headers
	if [[ $HEADERMOD == 'y' ]]; then
		cd /usr/local/src/nginx/modules || exit 1
		wget https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERMOD_VER}.tar.gz
		tar xaf v${HEADERMOD_VER}.tar.gz
	fi

	# Cache Purge
	if [[ $CACHEPURGE == 'y' ]]; then
		cd /usr/local/src/nginx/modules || exit 1
		git clone --depth 1 https://github.com/FRiCKLE/ngx_cache_purge
	fi

	cd /usr/local/src/nginx/ || exit 1
	wget -qO- http://nginx.org/download/nginx-${NGINX_VER}.tar.gz | tar zxf -
	cd nginx-${NGINX_VER} || exit 1

	if [[ ! -e /etc/nginx/nginx.conf ]]; then
		mkdir -p /etc/nginx
		cd /etc/nginx || exit 1
		wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/depolama.conf -O /etc/nginx/nginx.conf
	fi
	cd /usr/local/src/nginx/nginx-${NGINX_VER} || exit 1

	NGINX_OPTIONS="
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--user=nginx \
		--group=nginx \
		--with-cc-opt=-Wno-deprecated-declarations \
		--with-cc-opt=-Wno-ignored-qualifiers"

	NGINX_MODULES="--with-threads \
		--with-file-aio \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_mp4_module \
		--with-http_auth_request_module \
		--with-http_slice_module \
		--with-http_stub_status_module \
		--with-http_realip_module \
		--with-http_sub_module"

	if [[ $BROTLI == 'y' ]]; then
		NGINX_MODULES=$(
			echo "$NGINX_MODULES"
			echo "--add-module=/usr/local/src/nginx/modules/ngx_brotli"
		)
	fi

	if [[ $HEADERMOD == 'y' ]]; then
		NGINX_MODULES=$(
			echo "$NGINX_MODULES"
			echo "--add-module=/usr/local/src/nginx/modules/headers-more-nginx-module-${HEADERMOD_VER}"
		)
	fi

	if [[ $CACHEPURGE == 'y' ]]; then
		NGINX_MODULES=$(
			echo "$NGINX_MODULES"
			echo "--add-module=/usr/local/src/nginx/modules/ngx_cache_purge"
		)
	fi

	if [[ $VTS == 'y' ]]; then
		git clone --depth 1 --quiet https://github.com/vozlt/nginx-module-vts.git /usr/local/src/nginx/modules/nginx-module-vts
		NGINX_MODULES=$(
			echo "$NGINX_MODULES"
			echo --add-module=/usr/local/src/nginx/modules/nginx-module-vts
		)
	fi

	./configure $NGINX_OPTIONS $NGINX_MODULES
	make -j "$(nproc)"
	make install

	strip -s /usr/sbin/nginx

	if [[ ! -e /lib/systemd/system/nginx.service ]]; then
		cd /lib/systemd/system/ || exit 1
		wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/nginx.service
		systemctl enable nginx
	fi

	if [[ ! -e /etc/logrotate.d/nginx ]]; then
		cd /etc/logrotate.d/ || exit 1
		wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/nginx-logrotate -O nginx
	fi

	if [[ ! -d /var/cache/nginx ]]; then
		mkdir -p /var/cache/nginx
	fi

	if [[ ! -d /etc/nginx/sites-available ]]; then
		mkdir -p /etc/nginx/sites-available
	fi
	if [[ ! -d /etc/nginx/sites-enabled ]]; then
		mkdir -p /etc/nginx/sites-enabled
	fi
	if [[ ! -d /etc/nginx/conf.d ]]; then
		mkdir -p /etc/nginx/conf.d
	fi

	systemctl restart nginx

	if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
		cd /etc/apt/preferences.d/ || exit 1
		echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' >nginx-block
	fi

	mkdir /home/html
	wget https://raw.githubusercontent.com/fastdepo/fastpriviacy/master/index.html -O /home/html/index.html
	rm -r /usr/local/src/nginx
	clear
	echo "Kurulum Başarılı.. > Nginx DEPOLAMA"
	exit
	;;
*) # Exit
	exit
	;;

esac
