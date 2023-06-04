#!/usr/bin/env bash

if [[ "$EUID" -ne 0 ]] ; then
  printf "EUID is not equal 0 (no root user)\\n"
  exit 1
fi

function info () {
  printf "[ \033[00;34m..\033[0m ] $1"
}

function infoline () {
  printf "\r[ \033[00;34m-\033[0m ] $1\n"
}

function user () {
  printf "\r[ \033[0;33m?\033[0m ] $1 "
}

function success () {
  printf "\r\033[2K[ \033[00;32mOK\033[0m ] $1\n"
}

function fail () {
  printf "\r\033[2K[\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

if [[ "$OSTYPE" == "darwin"* ]] ; then
  _os_name="darwin"
  _os_version=""
  _os_id="darwin"
  readonly _dir=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")

elif [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "linux-musl" ]] ; then
  readonly _dir=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")

  if [[ -f /etc/os-release ]] ; then
    source /etc/os-release
    _os_name="$NAME"
    _os_version="$VERSION_ID"
    _os_id="$ID"
    _os_id_like="$ID_LIKE"

  elif type lsb_release >/dev/null 2>&1 ; then
    _os_name=$(lsb_release -si)
    _os_version=$(lsb_release -sr)

  elif [[ -f /etc/lsb-release ]] ; then
    source /etc/lsb-release
    _os_name="$DISTRIB_ID"
    _os_version="$DISTRIB_RELEASE"

  elif [[ -f /etc/debian_version ]] ; then
    _os_name="Debian"
    _os_version=$(cat /etc/debian_version)

  elif [[ -f /etc/redhat-release ]] ; then
    _os_name=$(awk '{print $1}' /etc/redhat-release)
    _os_version=$(awk '{print $4}' /etc/redhat-release)

  elif [[ -f /etc/centos-release ]] ; then
    _os_name=$(awk '{print $1}' /etc/centos-release)
    _os_version=$(awk '{print $4}' /etc/centos-release)

  else
    fail "Autoinstaller is not available on your system."
  fi
fi

if [[ "$_os_name" == "darwin" ]] || \
   [[ "$_os_id" == "darwin" ]] || \
   [[ "$_os_id_like" == "darwin" ]] ; then

  _tread

  # System tools.
  brew install coreutils gnu-getopt gnu-sed openssl curl bc jq php72 \
  libmaxminddb geoipupdate python rsync

  # Install go.
  wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz && \
  tar -xvf go1.13.5.linux-amd64.tar.gz && \
  mv go /usr/lib &&
  ln -s /usr/lib/go/bin/go /usr/bin/go

  brew install node composer

  # For Mozilla-Observatory.
  npm install -g observatory-cli

  # For Ssllabs API.
  brew install ssllabs-scan

  # For mixed-content-scan.
  composer global require bramus/mixed-content-scan

  # For testssl.sh.
  brew install testssl

  # For Nmap NSE Library.
  brew install nmap

  git clone https://github.com/scipag/vulscan /opt/scipag_vulscan && \
  ln -s /opt/scipag_vulscan /usr/share/nmap/scripts/vulscan

  # For WhatWaf.
  # git clone https://github.com/ekultek/whatwaf.git /opt/whatwaf
  # cd /opt/whatwaf

  # chmod +x whatwaf.py
  # pip install -r requirements.txt
  # ./setup.sh install
  # cp ~/.whatwaf/.install/bin/whatwaf /usr/bin/whatwaf
  # ./setup.sh uninstall

  # pip install -r requirements.txt
  # ln -s /opt/whatwaf/whatwaf /usr/bin/whatwaf

  # For Wafw00f.
  git clone https://github.com/EnableSecurity/wafw00f /opt/wafw00f
  cd /opt/wafw00f
  # pip install --upgrade pip
  # pip install --upgrade setuptools
  python setup.py install

  # For SubFinder
  # go get github.com/subfinder/subfinder && \
  go get -v github.com/projectdiscovery/subfinder/cmd/subfinder && \
  ln -s "${GOPATH}/bin/subfinder" /usr/bin/subfinder

  # For Nghttp2
  brew install nghttp2

  if [[ -e "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]] ; then

    cd /usr/share/GeoIP
    wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz
    gzip -d GeoLite2-Country.mmdb.gz

  fi

  geoipupdate

elif [[ "$_os_name" == "debian" ]] || \
     [[ "$_os_name" == "ubuntu" ]] || \
     [[ "$_os_id" == "debian" ]] || \
     [[ "$_os_id" == "ubuntu" ]] || \
     [[ "$_os_id_like" == "debian" ]] || \
     [[ "$_os_id_like" == "ubuntu" ]] ; then

  _tread

  # System tools.
  apt-get update

  # Install go.
  wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz && \
  tar -xvf go1.13.5.linux-amd64.tar.gz && \
  mv go /usr/lib &&
  ln -s /usr/lib/go/bin/go /usr/bin/go

  apt-get install -y ca-certificates dnsutils gnupg apt-utils unzip openssl \
  curl bc jq mmdb-bin libmaxminddb0 libmaxminddb-dev python python-pip rsync

  apt-get install -y --reinstall procps

  wget -c https://github.com/maxmind/geoipupdate/releases/download/v4.0.3/geoipupdate_4.0.3_linux_amd64.deb &&
  dpkg -i geoipupdate_4.0.3_linux_amd64.deb

  # For Mozilla-Observatory.
  curl -sL https://deb.nodesource.com/setup_10.x | bash -
  apt-get install -y nodejs
  npm install -g observatory-cli

  # For Ssllabs API.
  go get github.com/ssllabs/ssllabs-scan
  # It's important - PATH is hardcoded in src/settings.
  ln -s /opt/go/bin/ssllabs-scan /usr/bin/ssllabs-scan

  # PHP 7.0
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
  # alternative:
  #   add-apt-repository ppa:ondrej/php
  apt-get update
  # apt-get install -y php7.3-curl php7.3-xml php7.3-cli php7.3-mbstring
  apt-get install -y php7.0-curl php7.0-xml php7.0-cli php7.0-mbstring

  # For mixed-content-scan.
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  composer global require bramus/mixed-content-scan

  # It's important - PATH is hardcoded in src/settings.
  if [[ -d ${HOME}/.composer ]] ; then

    ln -s /root/.composer/vendor/bramus/mixed-content-scan/bin/mixed-content-scan \
    /usr/bin/mixed-content-scan

  elif [[ -d ${HOME}/.config/composer ]] ; then

    ln -s /root/.config/composer/vendor/bramus/mixed-content-scan/bin/mixed-content-scan \
    /usr/bin/mixed-content-scan

  fi

  # For testssl.sh.
  git clone --depth 1 https://github.com/drwetter/testssl.sh.git /opt/testssl.sh
  chmod +x /opt/testssl.sh/testssl.sh
  ln -s /opt/testssl.sh/testssl.sh /usr/bin/testssl.sh

  # For Nmap NSE Library.
  # apt-get install nmap
  wget https://nmap.org/dist/nmap-7.70-1.x86_64.rpm
  apt -y install alien
  alien nmap-7.70-1.x86_64.rpm
  dpkg -i nmap_7.70-2_amd64.deb

  git clone https://github.com/scipag/vulscan /opt/scipag_vulscan && \
  ln -s /opt/scipag_vulscan /usr/share/nmap/scripts/vulscan

  # For WhatWaf.
  # git clone https://github.com/ekultek/whatwaf.git /opt/whatwaf
  # cd /opt/whatwaf

  # chmod +x whatwaf.py
  # pip install -r requirements.txt
  # ./setup.sh install
  # cp ~/.whatwaf/.install/bin/whatwaf /usr/bin/whatwaf
  # ./setup.sh uninstall

  # pip install -r requirements.txt
  # ln -s /opt/whatwaf/whatwaf /usr/bin/whatwaf

  # For Wafw00f.
  git clone https://github.com/EnableSecurity/wafw00f /opt/wafw00f
  cd /opt/wafw00f
  # pip install --upgrade pip
  # pip install --upgrade setuptools
  python setup.py install

  # For SubFinder
  # go get github.com/subfinder/subfinder && \
  go get -v github.com/projectdiscovery/subfinder/cmd/subfinder && \
  ln -s "${GOPATH}/bin/subfinder" /usr/bin/subfinder

  # For Nghttp2
  apt-get install nghttp2

  if [[ -e "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]] ; then

    cd /usr/share/GeoIP
    wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz
    gzip -d GeoLite2-Country.mmdb.gz

  fi

  geoipupdate

elif [[ "$_os_name" == "CentOS Linux" ]] || \
     [[ "$_os_id" == "centos" ]] || \
     [[ "$_os_id_like" == "rhel fedora" ]] ; then

  _tread

  # Install curl.
  rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/city-fan.org-release-2-1.rhel7.noarch.rpm && \
  yum-config-manager --enable city-fan.org && \
  yum update -y curl

  # Install go.
  wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz && \
  tar -xvf go1.13.5.linux-amd64.tar.gz && \
  mv go /usr/lib &&
  ln -s /usr/lib/go/bin/go /usr/bin/go

  yum install -y ca-certificates bind-utils gnupg unzip openssl \
  bc jq mmdb2 mmdb2-devel libmaxminddb libmaxminddb-devel python python-pip rsync

  # wget -c https://github.com/maxmind/geoipupdate/releases/download/v4.0.3/geoipupdate_4.0.3_linux_amd64.rpm &&
  # rpm -Uvh geoipupdate_4.0.3_linux_amd64.rpm

  # For Mozilla-Observatory.
  wget http://nodejs.org/dist/v0.10.30/node-v0.10.30-linux-x64.tar.gz
  tar --strip-components 1 -xzvf node-v* -C /usr/local
  npm install -g observatory-cli

  # For Ssllabs API.
  go get github.com/ssllabs/ssllabs-scan
  # It's important - PATH is hardcoded in src/settings.
  ln -s /opt/go/bin/ssllabs-scan /usr/bin/ssllabs-scan

  # PHP 7.0
  yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
  yum-config-manager --enable remi-php70

  yum install -y php-curl php-xml php-cli php-mbstring

  # For mixed-content-scan.
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  composer global require bramus/mixed-content-scan

  # It's important - PATH is hardcoded in src/settings.
  if [[ -d ${HOME}/.composer ]] ; then

    ln -s /root/.composer/vendor/bramus/mixed-content-scan/bin/mixed-content-scan \
    /usr/bin/mixed-content-scan

  elif [[ -d ${HOME}/.config/composer ]] ; then

    ln -s /root/.config/composer/vendor/bramus/mixed-content-scan/bin/mixed-content-scan \
    /usr/bin/mixed-content-scan

  fi

  # For testssl.sh.
  git clone --depth 1 https://github.com/drwetter/testssl.sh.git /opt/testssl.sh
  chmod +x /opt/testssl.sh/testssl.sh
  ln -s /opt/testssl.sh/testssl.sh /usr/bin/testssl.sh

  # For Nmap NSE Library.
  # apt-get install nmap
  wget https://nmap.org/dist/nmap-7.70-1.x86_64.rpm
  rpm -Uvh nmap-7.70-1.x86_64.rpm

  git clone https://github.com/scipag/vulscan /opt/scipag_vulscan && \
  ln -s /opt/scipag_vulscan /usr/share/nmap/scripts/vulscan


  # For Wafw00f.
  git clone https://github.com/EnableSecurity/wafw00f /opt/wafw00f
  cd /opt/wafw00f
  # pip install --upgrade pip
  # pip install --upgrade setuptools
  python setup.py install

  # For SubFinder
  # go get github.com/subfinder/subfinder && \
  go get -v github.com/projectdiscovery/subfinder/cmd/subfinder && \
  ln -s "${GOPATH}/bin/subfinder" /usr/bin/subfinder

  wget -P /usr/share/GeoIP https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz && \
  gunzip /usr/share/GeoIP2/*.mmdb.gz

  # For Nghttp2
  yum install nghttp2

  if [[ -e "/usr/share/GeoIP/GeoLite2-Country.mmdb" ]] ; then

    cd /usr/share/GeoIP
    wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz
    gzip -d GeoLite2-Country.mmdb.gz

  fi

  # geoipupdate

else

  _bye

fi

cd "${_dir}" && rm -fr "${_tmp}"