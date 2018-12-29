# $FreeBSD$

PORTNAME=	trident-updatemgr
PORTVERSION=	201812290806
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
GH_PROJECT=	trident-updatemgr
GH_TAGNAME=	77be8a53488ad9420423cf01618aa11eeed9f425
WRKSRC_SUBDIR=	src-qt5

.include <bsd.port.mk>
