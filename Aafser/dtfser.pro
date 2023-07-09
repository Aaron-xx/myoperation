TEMPLATE = app
CONFIG += console
CONFIG -= qt

INCLUDEPATH += ../Aaron.OS/

SOURCES += main.c \
    hdraw.c \
    ../Aaron.OS/utility.c

HEADERS += \
    hdraw.h \
    ../Aaron.OS/utility.h

