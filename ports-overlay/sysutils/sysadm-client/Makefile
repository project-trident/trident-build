# $FreeBSD$

PORTNAME=	sysadm-client
PORTVERSION=	201812241140
CATEGORIES=	sysutils

MAINTAINER=	jt@ixsystems.com
COMMENT=	SysAdm Qt5 Client

LICENSE=	BSD3CLAUSE

WRKSRC_SUBDIR=	src-qt5
USES=		pkgconfig tar:xz qmake ssl qt:5
USE_QT=	core gui network websockets widgets svg concurrent \
    buildtools_build linguist_build

USE_GL+=	gl
MAKE_ARGS=	PREFIX=${STAGEDIR}${PREFIX}

USE_GITHUB=	yes
GH_ACCOUNT=	trueos
GH_PROJECT=	sysadm-ui-qt
GH_TAGNAME=	915032be3b4a6016677bccf31f7721f912abaa7b

.include <bsd.port.pre.mk>

.if ${OSVERSION} < 1000000
IGNORE=		requires FreeBSD 10 or later
.endif

.include <bsd.port.post.mk>
