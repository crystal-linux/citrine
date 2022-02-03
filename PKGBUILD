# Maintainer: Matt C <mdc028[at]bucknell[dot]edu>

pkgname=citrine
pkgver=3.2.6
pkgrel=1
pkgdesc="Crystal Linux Script for installing the system"
arch=('any')
url="https://git.tar.black/crystal/programs/citrine"
license=('custom')
source=("citrine.sh" "citrine.internal.sh")
depends=('arch-install-scripts' 'util-linux' 'parted' 'dialog' 'dosfstools' 'ntp')
md5sums=('c16f9c01d656886b905071cb5477d3e3'
         '1222056ce25a2f5c31fc074ae46aa7af')

package() {
    chmod +x *.sh
    mkdir -p ${pkgdir}/usr/bin
    mkdir -p ${pkgdir}/etc/citrine
    echo $pkgver > ${pkgdir}/etc/citrine/version
    cp citrine.sh ${pkgdir}/usr/bin/citrine
    cp citrine.internal.sh ${pkgdir}/usr/bin/citrine.internal
}
