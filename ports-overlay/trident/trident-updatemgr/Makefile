# $FreeBSD$

PORTNAME=	trident-updatemgr
PORTVERSION=	201907150946
CATEGORIES=	trident

MAINTAINER=	ken@ixsystems.com
COMMENT=	Graphical Update Manager for Project Trident

LICENSE=	BSD2CLAUSE

RUN_DEPENDS=	sysup>=0:sysutils/sysup \
		beadm>=0:sysutils/beadm

USES=	qmake qt:5
USE_QT=	core gui widgets svg network x11extras \
		buildtools_build linguist_build
USE_GITHUB=	yes
GH_ACCOUNT=	project-trident
GH_PROJECT=	trident-utilities
GH_TAGNAME=	723159b1cca0db7e4a1e3ba1ca39a7d6dfce9bc6
WRKSRC_SUBDIR=	src-qt5/updatemgr

.include <bsd.port.mk>
