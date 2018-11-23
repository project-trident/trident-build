# $FreeBSD$

PORTNAME=	trident-icons
PORTVERSION=	201811222056
CATEGORIES=	trident

MAINTAINER=	jt@ixsystems.com
COMMENT=	Icon Themes for Project Trident

LICENSE=	BSD3CLAUSE

USE_GITHUB=	yes
GH_ACCOUNT=	project-trident
GH_PROJECT=	trident-icons
GH_TAGNAME=	0a20201c49b8553b3944675c17bedfb223b1e90d

NO_BUILD=	yes

do-install:
	${MKDIR} ${STAGEDIR}/usr/local/share/icons
	cd ${WRKSRC} && ${WRKSRC}/install-local.sh ${STAGEDIR}/usr/local/share/icons
	(cd ${STAGEDIR}/; ${FIND} . -not -type d \
		| ${SED} -e 's,^\./,/,g' \
		| ${AWK} '{print length, $$0}' | ${SORT} -rn \
		| cut -d " " -f 2- \
		| ${AWK} '{print $$0 }' >> ${TMPPLIST})

.include <bsd.port.mk>
