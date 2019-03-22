# $FreeBSD$

PORTNAME=	lumina-calculator
PORTVERSION=	1.4.3
PORTREVISION=	201903221127
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
GH_TAGNAME=	c4ee9204db28c655aab5b7fa1382cdde70bbd6d1
WRKSRC_SUBDIR=	src-qt5

.if${PORT_OPTIONS:MI18N}
USE_QT+= linguist_build
QMAKE_ARGS+=CONFIG+=WITH_I18N
.endif

.include <bsd.port.mk>
