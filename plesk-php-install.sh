#!/usr/bin/env bash
 
# Get version from first command line parameter
version=$1

if [ -z "$version" ]; then
  echo "Please specify a version to download, e.g. '5.5.11'"
  exit 1
fi

uid=`id -u`
if [[ $uid > 0 ]]; then
  echo "This script needs to be run as root."
  exit 2
fi

# Create download URL for german mirror
phpUrl=http://www.php.net/get/php-${version}.tar.bz2/from/de2.php.net/mirror
# Create temp filename
phpTarFile=/tmp/php-${version}.tar.bz2

echo "Install build build essentials"
apt-get install -y build-essential

echo "Install PHP5 build dependencies"
apt-get build-dep -y php5

echo "Install libraries"
apt-get install -y libfcgi-dev libfcgi0ldbl libjpeg62-dbg libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2 libxml2-dev libssl-dev pkg-config curl libcurl4-nss-dev enchant libenchant-dev libjpeg8 libjpeg8-dev libpng12-0 libpng12-dev libvpx1 libvpx-dev libfreetype6 libfreetype6-dev libt1-5 libt1-dev libgmp10 libgmp-dev libicu48 libicu-dev mcrypt libmcrypt4 libmcrypt-dev libpspell-dev libedit2 libedit-dev libsnmp15 libsnmp-dev libxslt1.1 libxslt1-dev libbz2-dev libpq-dev

echo "Symlink libc-client.a to avoid error with --with-imap"
if [ ! -f /usr/lib/x86_64-linux-gnu/libc-client.a ]; then
  ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
fi

echo "Download php source if not exists or overwrite with newer version"
pushd .
cd /tmp/
wget -N ${phpUrl} -O php-${version}.tar.bz2
popd

# Check if file was downloaded
if [[ -f "${phpTarFile}" ]]; then
  # Untar the archive
  tar xjvf ${phpTarFile} -C /usr/local/src/ || (echo "downloaded file '${phpTarFile}' seems to be corrupt" && exit 1)

  # Save current path
  pushd .

  # Change dir to extracted PHP
  cd /usr/local/src/php-${version}/

  # Run the configure command
  ./configure --prefix=/usr/local/php-${version} --with-pdo-pgsql --with-zlib-dir --with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap --enable-calendar --with-curl --with-mcrypt --with-zlib --with-gd --with-pgsql --disable-rpath --enable-inline-optimization --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --with-mhash --enable-zip --with-pcre-regex --with-mysql --with-pdo-mysql --with-mysqli --with-jpeg-dir=/usr --with-png-dir=/usr --enable-gd-native-ttf --with-openssl --with-fpm-user=www-data --with-fpm-group=www-data --with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-imap --with-imap-ssl --with-kerberos --with-gettext --enable-fpm --enable-fastcgi

  # Run the make process using all processors
  make -j $(grep processor /proc/cpuinfo | wc -l)

  # Run make install
  make install

  # Copy dev php.ini to target directory
  cp /usr/local/src/php-${version}/php.ini-development /usr/local/php-${version}/etc/php.ini

  # Updae timezone to Europe/Berlin in php.ini
  sed -i "s#;date.timezone =#date.timezone = Europe/Berlin#" /usr/local/php-${version}/etc/php.ini

  # Remove PHP registration from plesk, this might fail but is ok
  /usr/local/psa/bin/php_handler --remove -id "fastcgi-${version}"

  # And finally we register PHP ${version} with Plesk
  /usr/local/psa/bin/php_handler --add -displayname "${version}" -path /usr/local/php-${version}/bin/php-cgi -phpini /usr/local/php-${version}/etc/php.ini -type fastcgi -id "fastcgi-${version}"
  popd
else
  echo "Unable to download ${phpUrl}"
fi
