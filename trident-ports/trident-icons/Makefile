# $FreeBSD$

PORTNAME=	trident-icons
PORTVERSION=	201808071511
CATEGORIES=	trident

MAINTAINER=	jt@ixsystems.com
COMMENT=	Icon Themes for Project Trident

LICENSE=	BSD3CLAUSE

USE_GITHUB=	yes
GH_ACCOUNT=	project-trident
GH_PROJECT=	trident-icons
GH_TAGNAME=	f0e9625c3d6d2b7e12da836e52f69b224b8bac74

NO_BUILD=	yes

do-install:
	${MKDIR} ${STAGEDIR}/usr/local/share/icons
	cd ${WRKSRC} && ${WRKSRC}/install-local.sh ${STAGEDIR}/usr/local/share/icons

.include <bsd.port.mk>
