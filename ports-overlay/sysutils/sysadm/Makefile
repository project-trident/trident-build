# $FreeBSD$

PORTNAME=	sysadm
PORTVERSION=	201905231958
CATEGORIES=	sysutils

MAINTAINER=	jt@ixsystems.com
COMMENT=	SysAdm API server

LICENSE=	BSD3CLAUSE

WRKSRC_SUBDIR=	src
USES=		pkgconfig tar:xz qmake ssl qt:5
USE_QT=	concurrent core network buildtools_build qmake_build websockets sql
MAKE_ARGS=	PREFIX=${STAGEDIR}${PREFIX}

USE_GITHUB=	yes
GH_ACCOUNT=	trueos
GH_PROJECT=	sysadm
GH_TAGNAME=	d01826355905549bf83c07dcd09fb5e11696debc

.include <bsd.port.pre.mk>

.if ${OSVERSION} < 1000000
IGNORE=		requires FreeBSD 10 or later
.endif

.include <bsd.port.post.mk>
