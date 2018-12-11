# $FreeBSD$

PORTNAME=	sysadm
PORTVERSION=	201812110936
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
GH_TAGNAME=	b7fa03d2b863e433e8db9dd36fe6dbdf27c60870

.include <bsd.port.pre.mk>

.if ${OSVERSION} < 1000000
IGNORE=		requires FreeBSD 10 or later
.endif

.include <bsd.port.post.mk>
