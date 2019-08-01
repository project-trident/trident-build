# $FreeBSD$

PORTNAME=	qsudo
PORTVERSION=	201908010827
CATEGORIES=	sysutils

MAINTAINER=	ken@ixsystems.com
COMMENT=	Qt sudo front-end

LICENSE=	BSD2CLAUSE
LICENSE_FILE=   ${WRKSRC}/../LICENSE

RUN_DEPENDS=	${LOCALBASE}/bin/sudo:security/sudo

USES=           qt:5 qmake
USE_QT=        core gui widgets buildtools_build
MAKE_ARGS=      PREFIX=${STAGEDIR}${PREFIX}

QMAKE_ARGS=     CONFIG+="configure"

USE_GITHUB=	yes
GH_ACCOUNT=	project-trident
GH_PROJECT=	qsudo
GH_TAGNAME=	a033c91a22967c2ea73e2f34e5a0695e4ef80999

WRKSRC_SUBDIR=  src-qt5
LDFLAGS+=       -Wl,--as-needed

PLIST_FILES=	bin/qsudo

.include <bsd.port.mk>
