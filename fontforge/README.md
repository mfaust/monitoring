Build FontForge in Docker
=========================

FontForge website: https://fontforge.github.io

Build Docker container
----------------------

```docker build -t=fontforge .```

Start a FontForge build in Docker container
-------------------------------------------

```
mkdir build
docker run --rm -v "$PWD"/build:/fontforge -v "$PWD":/build -w /fontforge -e VERSION=20160404 fontforge bash /build/build.sh
```

The binaries are in build/fontforge-VERSION.tar.gz
