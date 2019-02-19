# $FreeBSD$

PORTNAME=	lumina-screenshot
PORTVERSION=	1.4.2
PORTREVISION=	201902191051
CATEGORIES=	deskutils

MAINTAINER=	jt@ixsystems.com
COMMENT=	Screenshot utility from the Lumina Desktop

LICENSE=	BSD3CLAUSE

CONFLICTS_INSTALL=	lumina-1.2.*

OPTIONS_DEFINE=	I18N
OPTIONS_SUB=		yes
OPTIONS_DEFAULT=	I18N
I18N_DESC= Install localization files

.include <bsd.port.options.mk>

MAKE_JOBS_UNSAFE=yes

USES=		qmake qt:5
USE_QT=		core gui widgets network svg \
		buildtools_build x11extras concurrent multimedia
USE_GITHUB=	yes
GH_ACCOUNT=	lumina-desktop
GH_PROJECT=	lumina
GH_TAGNAME=	216055b791d2d159206c67a4a88ee5acd2142255
WRKSRC_SUBDIR=	src-qt5/desktop-utils/${PORTNAME}

.if${PORT_OPTIONS:MI18N}
USE_QT+= linguist_build
QMAKE_ARGS+=CONFIG+=WITH_I18N
.endif

.include <bsd.port.mk>
