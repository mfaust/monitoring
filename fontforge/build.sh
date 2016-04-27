VERSION=${VERSION:-"20160404"}
curl -o fontforge.zip https://codeload.github.com/fontforge/fontforge/zip/${VERSION}
unzip -qo fontforge.zip
cd fontforge-${VERSION}
./bootstrap
./configure --without-x
make install
cd ..
tar czf fontforge-${VERSION}.tar.gz /usr/local/bin /usr/local/lib
fontforge -v
