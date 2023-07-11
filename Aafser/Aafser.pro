TEMPLATE = app
CONFIG += console
CONFIG -= qt

DEFINES += DTFSER

INCLUDEPATH += ../Aaron.OS/

SOURCES += main.c \
    hdraw.c \
    ../Aaron.OS/utility.c \
    ../Aaron.OS/fs.c

HEADERS += \
    hdraw.h \
    ../Aaron.OS/utility.h \
    ../Aaron.OS/fs.h

