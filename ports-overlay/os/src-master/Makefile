# $FreeBSD$

PORTNAME=	src
PORTVERSION=	19.06
PORTREVISION=	20190314
CATEGORIES=	os

MAINTAINER=	kris@ixsystems.com
COMMENT=	Port for the OS base sources

USE_GITHUB=	yes
GH_ACCOUNT=	trueos
GH_PROJECT=	trueos
GH_TAGNAME=	64aa824d79ccc17a12b740f3253abdcc0e3195ac

PREFIX=/
SRCDIR?=/usr/src
NO_BUILD=	yes
WITHOUT_FBSD10_FIX=	yes
PKG_ABISTRING=	FreeBSD:13:${ARCH}
LOCAL_SDIR?=	/usr/local_source
.if exists(${LOCAL_SDIR}/${PORTNAME})
WRKSRC=	${LOCAL_SDIR}/${PORTNAME}
.endif

.include <bsd.port.pre.mk>

.if exists(${LOCAL_SDIR}/${PORTNAME})
checksum fetch:
	${ECHO_MSG} ${.TARGET} not needed because building direct
.endif

do-install:
	${MKDIR} -p ${STAGEDIR}${SRCDIR}
	${TAR} cf - -C ${WRKSRC} --exclude .git --exclude .svn . | ${TAR} xpf - -C ${STAGEDIR}${SRCDIR}
	(cd ${STAGEDIR}; ${FIND} . \( -type f -o -type l \) \
		| ${SED} -e 's,^\./,,g' \
		| ${AWK} '{print length, $$0}' | ${SORT} -rn \
		| ${AWK} '{print $$2 }' >> ${TMPPLIST})
	(cd ${STAGEDIR}; ${FIND} .${SRCDIR} \( -type d \) \
		| ${SED} -e 's,^\./,,g' \
		| ${AWK} '{print length, $$0}' | ${SORT} -rn \
		| ${AWK} '{print $$2 }' \
		| ${XARGS} -I '{}' echo "@dir {}" >> ${TMPPLIST})

.include <bsd.port.post.mk>
