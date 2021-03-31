dnl Process this file with autoconf to produce a configure script

dnl ------------------------------------------------
dnl Initialization and Versioning
dnl ------------------------------------------------

AC_INIT
AC_CONFIG_SRCDIR([mdct.c])
AC_CONFIG_MACRO_DIR([m4])

AC_CANONICAL_HOST
AC_CANONICAL_TARGET

AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE(libvorbisidec,1.2.1)

dnl AM_MAINTAINER_MODE only provides the option to configure to enable it
AM_MAINTAINER_MODE

dnl Library versioning

V_LIB_CURRENT=1
V_LIB_REVISION=3
V_LIB_AGE=0
AC_SUBST(V_LIB_CURRENT)
AC_SUBST(V_LIB_REVISION)
AC_SUBST(V_LIB_AGE)

dnl --------------------------------------------------
dnl Check for programs
dnl --------------------------------------------------

dnl save $CFLAGS since AC_PROG_CC likes to insert "-g -O2"
dnl if $CFLAGS is blank
cflags_save="$CFLAGS"
AC_PROG_CC
AC_PROG_CPP
CFLAGS="$cflags_save"

dnl AC_LIBTOOL_WIN32_DLL
dnl AC_PROG_LIBTOOL
LT_INIT([win32-dll])

# Test whenever ld supports -version-script
dnl AC_PROG_LD
dnl AC_PROG_LD_GNU
LT_PATH_LD

dnl check endianism
AC_C_BIGENDIAN


dnl --------------------------------------------------
dnl Set build flags based on environment
dnl --------------------------------------------------

dnl Set some target options

cflags_save="$CFLAGS"
ldflags_save="$LDFLAGS"
if test -z "$GCC"; then
        case $host in
        arm-*-*)
                DEBUG="-g -D_ARM_ASSEM_"
                CFLAGS="-O -D_ARM_ASSEM_"
                PROFILE="-p -g -O -D_ARM_ASSEM_" ;;
        *)
                DEBUG="-g"
                CFLAGS="-O"
                PROFILE="-g -p" ;;
        esac
else

        case $host in
        arm-*-*)
                DEBUG="-g -Wall -W -D__NO_MATH_INLINES -fsigned-char -D_ARM_ASSEM_"
                CFLAGS="-O2 -Wall -D_ARM_ASSEM_ -fsigned-char"
                PROFILE="-Wall -pg -g -O2 -D_ARM_ASSEM_ -fsigned-char -fno-inline-functions";;

        *)
                DEBUG="-g -Wall -W -D__NO_MATH_INLINES -fsigned-char"
                CFLAGS="-O2 -Wall -fsigned-char"
                PROFILE="-Wall -pg -g -O2 -fsigned-char -fno-inline-functions";;
        esac
fi
CFLAGS="$CFLAGS $cflags_save -D_REENTRANT"
LDFLAGS="$LDFLAGS $ldflags_save"


dnl --------------------------------------------------
dnl Options
dnl --------------------------------------------------

AC_ARG_ENABLE(low-accuracy,
   [AS_HELP_STRING([--enable-low-accuracy], [enable 32 bit only multiply operations])],
   CFLAGS="$CFLAGS -D_LOW_ACCURACY_"
)

AC_ARG_ENABLE(64kHz-limit,
   [AS_HELP_STRING([--enable-64kHz-limit], [limit playback ability to <64kHz files])],
   CFLAGS="$CFLAGS -DLIMIT_TO_64kHz"
)

dnl --------------------------------------------------
dnl Check for headers
dnl --------------------------------------------------

AC_CHECK_HEADERS(sys/types.h)
AC_CHECK_HEADER(memory.h,CFLAGS="$CFLAGS -DUSE_MEMORY_H",:)

dnl --------------------------------------------------
dnl Check for typedefs, structures, etc
dnl --------------------------------------------------

dnl none

dnl --------------------------------------------------
dnl Stack allocation mode
dnl --------------------------------------------------

AC_FUNC_ALLOCA


dnl --------------------------------------------------
dnl Version script (exported symbols control.)
dnl --------------------------------------------------

SHLIB_VERSION_ARG=""
if test "x$lt_cv_prog_gnu_ld" = "xyes"; then
   SHLIB_VERSION_ARG="-Wl,--version-script=Version_script"
fi
AC_SUBST(SHLIB_VERSION_ARG)


dnl --------------------------------------------------
dnl Do substitutions
dnl --------------------------------------------------

LIBS="$LIBS"

AC_SUBST(LIBS)
AC_SUBST(DEBUG)
AC_SUBST(PROFILE)

AC_CONFIG_FILES([Makefile Version_script vorbisidec.pc])
AC_OUTPUT
