# $FreeBSD$

PORTNAME=	lumina-pdf
PORTVERSION=	1.4.3
PORTREVISION=	201904031537
CATEGORIES=	deskutils

MAINTAINER=	ken@ixsystems.com
COMMENT=	PDF viewer from the Lumina Desktop

LICENSE=	BSD3CLAUSE

CONFLICTS_INSTALL=	lumina-1.2.*

OPTIONS_DEFINE=	I18N

OPTIONS_SINGLE=	RENDERER
OPTIONS_SINGLE_RENDERER=	POPPLER MUPDF

OPTIONS_SUB=		yes
OPTIONS_DEFAULT=	I18N POPPLER

I18N_DESC= Install localization files
POPPLER_DESC=	Use Poppler-qt5 backend renderer
MUPDF_DESC=		Use MuPDF backend renderer (broken)

.include <bsd.port.options.mk>

MAKE_JOBS_UNSAFE=yes

USES=		qmake qt:5
USE_QT=		core gui widgets network svg multimedia \
		buildtools_build x11extras concurrent printsupport
USE_GITHUB=	yes
GH_ACCOUNT=	lumina-desktop
GH_PROJECT=	lumina-pdf
GH_TAGNAME=	f0f69e0204005c29454159e74090bee6767beec0
WRKSRC_SUBDIR=	src-qt5

.if${PORT_OPTIONS:MPOPPLER}
QMAKE_ARGS+=	USE_POPPLER=true
LIB_DEPENDS+=	libpoppler-qt5.so:graphics/poppler-qt5
.elif${PORT_OPTIONS:MMUPDF}
QMAKE_ARGS+=	USE_MUPDF=true
LIB_DEPENDS+=	libmupdf.so:graphics/mupdf
.endif

.if${PORT_OPTIONS:MI18N}
USE_QT+= linguist_build
QMAKE_ARGS+=CONFIG+=WITH_I18N
.endif

.include <bsd.port.mk>
