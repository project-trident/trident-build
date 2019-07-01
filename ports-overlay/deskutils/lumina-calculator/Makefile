# $FreeBSD$

PORTNAME=	lumina-calculator
PORTVERSION=	1.5.0
PORTREVISION=	201907010802
CATEGORIES=	deskutils

MAINTAINER=	ken@project-trident.org
COMMENT=	Scientific calculator from the Lumina Desktop

LICENSE=	BSD3CLAUSE

CONFLICTS_INSTALL=	lumina-1.2.*

OPTIONS_DEFINE=	I18N
OPTIONS_SUB=		yes
OPTIONS_DEFAULT=	I18N
I18N_DESC= Install localization files

.include <bsd.port.options.mk>

MAKE_JOBS_UNSAFE=yes

USES=           qmake qt:5
USE_GL=		gl
USE_XORG=	x11
USE_QT=		core gui widgets svg \
		buildtools_build
USE_GITHUB=	yes
GH_ACCOUNT=	lumina-desktop
GH_PROJECT=	lumina-calculator
GH_TAGNAME=	ccb792fc713aa7163fffd37fc20c83ffe9ca7523
WRKSRC_SUBDIR=	src-qt5

.if${PORT_OPTIONS:MI18N}
USE_QT+= linguist_build
QMAKE_ARGS+=CONFIG+=WITH_I18N
.endif

.include <bsd.port.mk>
