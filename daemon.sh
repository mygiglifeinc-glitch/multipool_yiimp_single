#!/usr/bin/env bash

#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/.wireguard.install.cnf"

# Download a source archive over HTTPS and verify its SHA-256 checksum.
#   fetch_verified URL SHA256 FILE
function fetch_verified {
	local url=$1 sha256=$2 file=$3
	hide_output sudo curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$file" "$url"
	if ! echo "${sha256}  ${file}" | sha256sum -c --status -; then
		echo -e "$RED Checksum verification failed for ${url}, aborting.$COL_RESET"
		sudo rm -f "$file"
		exit 1
	fi
}

# Build a static Berkeley DB (C and C++ API) into an isolated prefix.
#   build_berkeley_db URL SHA256 SOURCE_DIR PREFIX
function build_berkeley_db {
	local url=$1 sha256=$2 src=$3 prefix=$4
	local archive atomic_h
	archive=$(basename "$url")
	sudo mkdir -p "$prefix"
	fetch_verified "$url" "$sha256" "$archive"
	hide_output sudo tar -xzf "$archive"
	# Newer compilers ship a builtin with the same name as a function in
	# Berkeley DB's atomic.h (same fix as bitcoin's install_db4.sh).
	if [ -f "$src/dbinc/atomic.h" ]; then atomic_h="$src/dbinc/atomic.h"; else atomic_h="$src/src/dbinc/atomic.h"; fi
	sudo sed -i 's/__atomic_compare_exchange/__atomic_compare_exchange_db/g' "$atomic_h"
	cd "$src/build_unix" || exit 1
	# The old C code does not build with the stricter defaults of GCC 14+.
	hide_output sudo env \
		CFLAGS="-O2 -std=gnu17 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=int-conversion" \
		CXXFLAGS="-O2 -std=gnu++14" \
		../dist/configure --enable-cxx --disable-shared --with-pic --prefix="$prefix"
	hide_output sudo make -j"$(nproc)"
	hide_output sudo make install
	cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
	sudo rm -rf "$archive" "$src"
}

echo -e " Installing additional system files required for daemons...$COL_RESET"
hide_output sudo apt-get update
apt_install build-essential libtool autotools-dev \
	automake pkg-config libssl-dev libevent-dev bsdmainutils git libboost-all-dev libminiupnpc-dev \
	qttools5-dev qttools5-dev-tools libprotobuf-dev \
	protobuf-compiler libqrencode-dev libzmq3-dev libgmp-dev libsodium-dev zlib1g-dev cmake unzip

sudo mkdir -p "$STORAGE_ROOT/yiimp/yiimp_setup/tmp"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
echo -e "$GREEN Additional System Files Completed...$COL_RESET"

echo -e " Building Berkeley 4.8, this may take several minutes...$COL_RESET"
build_berkeley_db 'https://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz' \
	12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef \
	db-4.8.30.NC "$STORAGE_ROOT/berkeley/db4/"
echo -e "$GREEN Berkeley 4.8 Completed...$COL_RESET"

echo -e " Building Berkeley 5.1, this may take several minutes...$COL_RESET"
build_berkeley_db 'https://download.oracle.com/berkeley-db/db-5.1.29.tar.gz' \
	a943cb4920e62df71de1069ddca486d408f6d7a09ddbbb5637afe7a229389182 \
	db-5.1.29 "$STORAGE_ROOT/berkeley/db5/"
echo -e "$GREEN Berkeley 5.1 Completed...$COL_RESET"

echo -e " Building Berkeley 5.3, this may take several minutes...$COL_RESET"
build_berkeley_db 'https://download.oracle.com/berkeley-db/db-5.3.28.tar.gz' \
	e0a992d740709892e81f9d93f06daf305cf73fb81b545afe72478043172c3628 \
	db-5.3.28 "$STORAGE_ROOT/berkeley/db5.3/"
echo -e "$GREEN Berkeley 5.3 Completed...$COL_RESET"

#####################################################
# Legacy OpenSSL 1.0.2 for old coin daemons ONLY.
#
# Some old coin daemons do not build against OpenSSL 3. For those, OpenSSL
# 1.0.2u (the last public 1.0.2 release, end of life and unsupported) is built
# into its own prefix, $STORAGE_ROOT/openssl. It is NOT installed system wide,
# does not touch the system OpenSSL and is not added to the linker path. A coin
# daemon only uses it when explicitly configured with that prefix, e.g.
#   CPPFLAGS=-I$STORAGE_ROOT/openssl/include LDFLAGS=-L$STORAGE_ROOT/openssl/lib
#####################################################
echo -e " Building legacy OpenSSL 1.0.2u into $STORAGE_ROOT/openssl, this may take several minutes...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
fetch_verified 'https://github.com/openssl/openssl/releases/download/OpenSSL_1_0_2u/openssl-1.0.2u.tar.gz' \
	ecd0c6ffb493dd06707d38b14bb4d8c2288bb7033735606569d8f90f89669d16 \
	openssl-1.0.2u.tar.gz
hide_output sudo tar -xzf openssl-1.0.2u.tar.gz
cd openssl-1.0.2u || exit 1
hide_output sudo ./config --prefix="$STORAGE_ROOT/openssl" --openssldir="$STORAGE_ROOT/openssl" shared zlib
hide_output sudo make
hide_output sudo make install_sw
cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
sudo rm -rf openssl-1.0.2u.tar.gz openssl-1.0.2u
echo -e "$GREEN OpenSSL 1.0.2u Completed...$COL_RESET"

echo -e " Building bls-signatures, this may take several minutes...$COL_RESET"
cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
sudo rm -rf bls-signatures-20181101
hide_output sudo git clone -q --depth 1 -b v20181101 -- https://github.com/codablock/bls-signatures.git bls-signatures-20181101
# Pin the exact commit the v20181101 tag pointed to when this was written.
if [ "$(sudo git -C bls-signatures-20181101 rev-parse HEAD)" != "e30ad8e8f220cf9f7b0a76440fee563f8e27b311" ]; then
	echo -e "$RED bls-signatures v20181101 does not match the expected commit, aborting.$COL_RESET"
	exit 1
fi
cd bls-signatures-20181101 || exit 1
# Fix "size of array element is not a multiple of its alignment" with GCC 11+
# (put the alignment on the struct instead of the typedef).
sudo sed -i -E 's/ALIGNME\( *64 *\) typedef struct/typedef struct ALIGNME(64)/' contrib/relic/src/md/blake2.h
hide_output sudo cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .
# Only build the library, the bundled tests don't compile with current glibc.
hide_output sudo make -j"$(nproc)" chiabls
hide_output sudo make install/fast
cd "$STORAGE_ROOT/yiimp/yiimp_setup/tmp" || exit 1
sudo rm -rf bls-signatures-20181101
echo -e "$GREEN bls-signatures Completed...$COL_RESET"

echo -e " Building blocknotify.sh...$COL_RESET"
if [[ "$wireguard" == "true" ]]; then
	source "$STORAGE_ROOT/yiimp/.wireguard.conf"
	BlocknotifyHost=${DBInternalIP}
else
	BlocknotifyHost=127.0.0.1
fi
sudo tee /usr/bin/blocknotify.sh > /dev/null <<EOF
#!/usr/bin/env bash
#####################################################
# Created by cryptopool.builders for crypto use...
#####################################################
exec blocknotify "${BlocknotifyHost}:\$1" "\$2" "\$3"
EOF
sudo chmod 755 /usr/bin/blocknotify.sh

echo
echo -e "$GREEN Daemon setup completed...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
