#include "hdraw.h"
#include "fs.h"
#include "utility.h"
#include "screen.h"
#include "list.h"

#ifdef DTFSER
#include <malloc.h>
#define Malloc malloc
#define Free free
#else
#include "memory.h"
#endif

#define FS_MAGIC       "AAFS-v1.0"
#define ROOT_MAGIC     "ROOT"
#define HEADER_SCT_IDX 0
#define ROOT_SCT_IDX   1
#define FIXED_SCT_SIZE 2
#define SCT_END_FLAG   ((uint)-1)
#define FE_BYTES       sizeof(FileEntry)
#define FD_BYTES       sizeof(FileDesc)
#define FE_ITEM_CNT    (SECT_SIZE / FE_BYTES)
#define MAP_ITEM_CNT   (SECT_SIZE/sizeof(uint))

typedef struct
{
    byte forJmp[4];
    char magic[32];
    uint sctNum;
    uint mapSize;
    uint freeNum;
    uint freeBegin;
} FSHeader;

typedef struct
{
    char magic[32];
    uint sctBegin;
    uint sctNum;
    uint lastBytes;
} FSRoot;

typedef struct
{
    char name[32];
    uint sctBegin;
    uint sctNum;
    uint lastBytes;
    uint type;
    uint inSctIdx;
    uint inSctOff;
    uint reserved[2];
} FileEntry;

typedef struct
{
    ListNode head;
    FileEntry fe;
    uint objIdx;
    uint offset;
    uint changed;
    byte cache[SECT_SIZE];
} FileDesc;

typedef struct
{
    uint* pSct;
    uint sctIdx;
    uint sctOff;
    uint idxOff;
} MapPos;

static List gFDList = {0};

void FSModInit()
{
    HDRawModInit();

    List_Init(&gFDList);
}

static void* ReadSector(uint si)
{
    void* ret = NULL;

    if(si != SCT_END_FLAG)
    {
        ret = Malloc(SECT_SIZE);

        if(!(ret && HDRawRead(si, (byte*)ret)))
        {
            Free(ret);
            ret = NULL;
        }
    }

    return ret;
}

static MapPos FindInMap(uint si)
{
    MapPos ret = {0};
    FSHeader* header = (si != SCT_END_FLAG) ? ReadSector(HEADER_SCT_IDX) : NULL;

    if(header)
    {
        uint offset = si - header->mapSize - FIXED_SCT_SIZE;
        uint sctOff = offset / MAP_ITEM_CNT;
        uint idxOff = offset % MAP_ITEM_CNT;
        uint* ps = ReadSector(sctOff + FIXED_SCT_SIZE);

        if(ps)
        {
            ret.pSct = ps;
            ret.sctIdx = si;
            ret.sctOff = sctOff;
            ret.idxOff = idxOff;
        }
    }

    Free(header);

    return ret;
}

static uint AllocSector()
{
    uint ret = SCT_END_FLAG;
    FSHeader* header = ReadSector(HEADER_SCT_IDX);

    if(header && (header->freeBegin != SCT_END_FLAG))
    {
        MapPos mp = FindInMap(header->freeBegin);

        if(mp.pSct)
        {
            uint* pInt = AddrOff(mp.pSct, mp.idxOff);
            uint next = *pInt;
            uint flag = 1;

            ret = header->freeBegin;

            header->freeBegin = next + FIXED_SCT_SIZE + header->mapSize;
            header->freeNum--;

            *pInt = SCT_END_FLAG;

            flag = flag && HDRawWrite(HEADER_SCT_IDX, (byte*)header);
            flag = flag && HDRawWrite(mp.sctOff + FIXED_SCT_SIZE, (byte*)mp.pSct);

            if(!flag)
            {
                ret = SCT_END_FLAG;
            }
        }

        Free(mp.pSct);
    }

    Free(header);

    return ret;
}

static uint FreeSector(uint si)
{
    FSHeader* header = (si != SCT_END_FLAG) ? ReadSector(HEADER_SCT_IDX) : NULL;
    uint ret = 0;

    if(header)
    {
        MapPos mp = FindInMap(si);

        if(mp.pSct)
        {
            uint* pInt = AddrOff(mp.pSct, mp.idxOff);

            *pInt = header->freeBegin - FIXED_SCT_SIZE - header->mapSize;

            header->freeBegin = si;
            header->freeNum++;

            ret = HDRawWrite(HEADER_SCT_IDX, (byte*)header) &&
                  HDRawWrite(mp.sctOff + FIXED_SCT_SIZE, (byte*)mp.pSct);
        }

        Free(mp.pSct);
    }

    Free(header);

    return ret;
}

static uint NextSector(uint si)
{
    FSHeader* header = (si != SCT_END_FLAG) ? ReadSector(HEADER_SCT_IDX) : NULL;
    uint ret = SCT_END_FLAG;

    if(header)
    {
        MapPos mp = FindInMap(si);

        if(mp.pSct)
        {
            uint* pInt = AddrOff(mp.pSct, mp.idxOff);

            if(*pInt != SCT_END_FLAG)
            {
                ret = *pInt + header->mapSize + FIXED_SCT_SIZE;
            }
        }

        Free(mp.pSct);
    }

    Free(header);

    return ret;
}

static uint FindLast(uint sctBegin)
{
    uint ret = SCT_END_FLAG;
    uint next = sctBegin;

    while(next != SCT_END_FLAG)
    {
        ret = next;
        next = NextSector(next);
    }

    return ret;
}

static uint FindPrev(uint sctBegin, uint si)
{
    uint ret = SCT_END_FLAG;
    uint next = sctBegin;

    while((next != SCT_END_FLAG) && (next != si))
    {
        ret = next;
        next = NextSector(next);
    }

    if(next == SCT_END_FLAG)
    {
        ret = SCT_END_FLAG;
    }

    return ret;
}

static uint FindIndex(uint sctBegin, uint idx)
{
    uint ret = sctBegin;
    uint i = 0;

    while((i < idx) && (ret != SCT_END_FLAG))
    {
        ret = NextSector(ret);

        i++;
    }

    return ret;
}

static uint MarkSector(uint si)
{
    uint ret = (si == SCT_END_FLAG) ? 1 : 0;
    MapPos mp = FindInMap(si);

    if(mp.pSct)
    {
        uint *pInt = AddrOff(mp.pSct, mp.idxOff);

        *pInt = SCT_END_FLAG;

        ret = HDRawWrite(mp.sctOff + FIXED_SCT_SIZE, (byte*)mp.pSct);
    }

    Free(mp.pSct);

    return ret;
}

static void AddToLast(uint sctBegin, uint si)
{
    uint last = FindLast(sctBegin);

    if(last != SCT_END_FLAG)
    {
        MapPos lmp = FindInMap(last);
        MapPos smp = FindInMap(si);

        if(lmp.pSct && smp.pSct)
        {
            if(lmp.sctOff == smp.sctOff)
            {
                uint* pInt = AddrOff(lmp.pSct, lmp.idxOff);

                *pInt = lmp.sctOff * MAP_ITEM_CNT + smp.idxOff;

                pInt = AddrOff(lmp.pSct, smp.idxOff);

                *pInt = SCT_END_FLAG;

                HDRawWrite(lmp.sctOff + FIXED_SCT_SIZE, (byte*)lmp.pSct);
            }
            else
            {
                uint* pInt = AddrOff(lmp.pSct, lmp.idxOff);

                *pInt = smp.sctOff * MAP_ITEM_CNT + smp.idxOff;

                pInt = AddrOff(smp.pSct, smp.idxOff);

                *pInt = SCT_END_FLAG;

                HDRawWrite(lmp.sctOff + FIXED_SCT_SIZE, (byte*)lmp.pSct);
                HDRawWrite(smp.sctOff + FIXED_SCT_SIZE, (byte*)smp.pSct);
            }
        }

        Free(lmp.pSct);
        Free(smp.pSct);
    }
}

static uint CheckStorage(FSRoot* fe)
{
    uint ret = 0;

    if( fe->lastBytes == SECT_SIZE )
    {
        uint si = AllocSector();

        if(si != SCT_END_FLAG)
        {
            if(fe->sctBegin == SCT_END_FLAG)
            {
                fe->sctBegin = si;
            }
            else
            {
                AddToLast(fe->sctBegin, si);
            }

            fe->sctNum++;
            fe->lastBytes = 0;

            ret = 1;
        }
    }

    return ret;
}

static uint CreateFileEntry(const char* name, uint sctBegin, uint lastBytes)
{
    uint ret = 0;
    uint last = FindLast(sctBegin);
    FileEntry* feBase = NULL;

     if((last != SCT_END_FLAG) && (feBase = (FileEntry*)ReadSector(last)))
    {
        uint offset = lastBytes / FE_BYTES;
        FileEntry* fe = AddrOff(feBase, offset);

        StrCpy(fe->name, name, sizeof(fe->name) - 1);

        fe->type = 0;
        fe->sctBegin = SCT_END_FLAG;
        fe->sctNum = 0;
        fe->inSctIdx = last;
        fe->inSctOff = offset;
        fe->lastBytes = SECT_SIZE;

        ret = HDRawWrite(last, (byte*)feBase);
    }

    Free(feBase);

    return ret;
}


static uint CreateInRoot(const char* name)
{
    FSRoot* root = (FSRoot*)ReadSector(ROOT_SCT_IDX);
    uint ret = 0;

    if (root)
    {
        CheckStorage(root);

        if( CreateFileEntry(name, root->sctBegin, root->lastBytes) )
        {
            root->lastBytes += FE_BYTES;
            ret = HDRawWrite(ROOT_SCT_IDX, (byte*)root);
        }
    }
    
}

static FileEntry* FindInSector(const char* name, FileEntry* feBase, uint cnt)
{
    FileEntry* ret = NULL;
    uint i = 0;

    for ( i = 0; i < cnt; i++)
    {
       FileEntry* fe = AddrOff(feBase, i);

       if( StrCmp(fe->name, name, -1))
       {
            ret = (FileEntry*)Malloc(FE_BYTES);

            if (ret)
            {
                *ret = *fe;
            }
            
            break;
       }
    }
    
    return ret;
}

static FileEntry* FindFileEntry(const char* name, uint sctBegin, uint sctNum, uint lastBytes)
{
    FileEntry* ret = NULL;
    uint next = sctBegin;
    uint i = 0;

    for(i=0; i<(sctNum-1); i++)
    {
        FileEntry* feBase = (FileEntry*)ReadSector(next);

        if(feBase)
        {
            ret = FindInSector(name, feBase, FE_ITEM_CNT);
        }

        Free(feBase);

        if(!ret)
        {
            next = NextSector(next);
        }
        else
        {
            break;
        }
    }

    if(!ret)
    {
        uint cnt = lastBytes / FE_BYTES;
        FileEntry* feBase = (FileEntry*)ReadSector(next);

        if(feBase)
        {
            ret = FindInSector(name, feBase, cnt);
        }

        Free(feBase);
    }

    return ret;
}

static FileEntry* FindInRoot(const char* name)
{
    FileEntry* ret = NULL;
    FSRoot* root = (FSRoot*)ReadSector(ROOT_SCT_IDX);

    if(root && root->sctNum)
    {
        ret = FindFileEntry(name, root->sctBegin, root->sctNum, root->lastBytes);
    }

    Free(root);

    return ret;

}

uint FCreate(const char* fn)
{
    uint ret = FExisted(fn);

    if( ret == FS_NONEXISTED )
    {
        ret = CreateInRoot(fn) ? FS_SUCCEED : FS_FAILED;
    }

    return ret;
}

uint FExisted(const char* fn)
{
    uint ret = FS_FAILED;

    if( fn )
    {
        FileEntry* fe = FindInRoot(fn);

        ret = fe ? FS_EXISTED : FS_NONEXISTED;

        Free(fe);
    }

    return ret;
}

uint FSFormat()
{
    FSHeader* header = (FSHeader*)Malloc(SECT_SIZE);
    FSRoot* root = (FSRoot*)Malloc(SECT_SIZE);
    uint* p = (uint*)Malloc(MAP_ITEM_CNT * sizeof(uint));
    uint ret = 0;

    if(header && root && p)
    {
        uint i = 0;
        uint j = 0;
        uint current = 0;

        StrCpy(header->magic, FS_MAGIC, sizeof(header->magic)-1);

        header->sctNum = HDRawSectors();
        header->mapSize = (header->sctNum - FIXED_SCT_SIZE) / 129 + !!((header->sctNum - FIXED_SCT_SIZE) % 129);
        header->freeNum = header->sctNum - header->mapSize - FIXED_SCT_SIZE;
        header->freeBegin = FIXED_SCT_SIZE + header->mapSize;

        ret = HDRawWrite(HEADER_SCT_IDX, (byte*)header);

        StrCpy(root->magic, ROOT_MAGIC, sizeof(root->magic)-1);

        root->sctNum = 0;
        root->sctBegin = SCT_END_FLAG;
        root->lastBytes = SECT_SIZE;

        ret = ret && HDRawWrite(ROOT_SCT_IDX, (byte*)root);

        for(i=0; ret && (i<header->mapSize) && (current<header->freeNum); i++)
        {
            for(j=0; j<MAP_ITEM_CNT; j++)
            {
                uint* pInt = AddrOff(p, j);

                if(current < header->freeNum)
                {
                    *pInt = current + 1;

                    if(current == (header->freeNum - 1))
                    {
                        *pInt = SCT_END_FLAG;
                    }

                    current++;
                }
                else
                {
                    break;
                }
            }

            ret = ret && HDRawWrite(i + FIXED_SCT_SIZE, (byte*)p);
        }
    }

    Free(header);
    Free(root);
    Free(p);

    return ret;
}

static uint IsOpened(const char* name)
{
    uint ret = 0;

    return ret;
}

static uint FreeFile(uint sctBegin)
{
    uint slider = sctBegin;
    uint ret = 0;

    while (slider != SCT_END_FLAG)
    {
        uint next = NextSector(slider);

        ret += FreeSector(slider);

        slider = next;
    }
    
    return ret;
}

static void MoveFileEntry(FileEntry* dst, FileEntry* src)
{
    uint inSctIdx = dst->inSctIdx;
    uint inSctOff = dst->inSctOff;

    *dst = *src;

    dst->inSctIdx = inSctIdx;
    dst->inSctOff = inSctOff;
}

static uint AdjustStorage(FSRoot* fe)
{
    uint ret = 0;

    if(!fe->lastBytes)
    {
        uint last = FindLast(fe->sctBegin);
        uint prev = FindPrev(fe->sctBegin, last);

        if(FreeSector(last) && MarkSector(prev))
        {
            fe->sctNum--;
            fe->lastBytes = SECT_SIZE;

            if(!fe->sctNum)
            {
                fe->sctBegin = SCT_END_FLAG;
            }

            ret = 1;
        }
    }

    return ret;
}

static uint EraseLast(FSRoot* fe, uint bytes)
{
    uint ret = 0;

    while (fe->sctNum && bytes)
    {
       if(bytes < fe->lastBytes)
       {
            fe->lastBytes -= bytes;
            ret += bytes;

            bytes = 0;
       }
       else
       {
            bytes -= fe->lastBytes;
            ret += fe->lastBytes;
            fe->lastBytes = 0;

            AdjustStorage(fe);
       }
    }
    
}

static uint DeleteInRoot(const char* name)
{
    FSRoot* root = (FSRoot*)ReadSector(ROOT_SCT_IDX);
    FileEntry* fe = FindInRoot(name);
    uint ret = 0;

    if(root && fe)
    {
        uint last = FindLast(root->sctBegin);
        FileEntry* feTarget = ReadSector(fe->inSctIdx);
        FileEntry* feLast = (last != SCT_END_FLAG) ? ReadSector(last) : NULL;

        if(feTarget && feLast)
        {
            uint lastOff = root->lastBytes / FE_BYTES - 1;
            FileEntry* lastItem = AddrOff(feLast, lastOff);
            FileEntry* targetItem = AddrOff(feTarget, fe->inSctOff);

            FreeFile(targetItem->sctBegin);

            MoveFileEntry(targetItem, lastItem);

            EraseLast(root, FE_BYTES);

            ret = HDRawWrite(ROOT_SCT_IDX, (byte*)root) &&
                    HDRawWrite(fe->inSctIdx, (byte*)feTarget);
        }

        Free(feTarget);
        Free(feLast);
    }

    Free(root);
    Free(fe);

    return ret;
}

uint FOpen(const char *fn)
{
    FileDesc* ret = NULL;

    if(fn && !IsOpened(fn))
    {
        FileEntry*fe = NULL;

        ret = (FileDesc*)Malloc(FD_BYTES);
        fe  = ret ? FindInRoot(fn) : NULL;

        if(ret && fe)
        {
            ret->fe = *fe;
            ret->objIdx = SCT_END_FLAG;
            ret->offset = SECT_SIZE;
            ret->changed = 0;

            List_Add(&gFDList, (ListNode*)ret);
        }

        Free(fe);
    }

    return (uint)ret;
}

static uint FlushCache(FileDesc* fd)
{
    uint ret = 1;

    if(fd->changed)
    {
        uint sctIdx = FindIndex(fd->fe.sctBegin, fd->objIdx);
        ret = 0;

        if( (sctIdx != SCT_END_FLAG) && (ret = HDRawWrite(sctIdx, fd->cache)) )
        {
            fd->changed = 0;
        }
    }
    
    return ret;
}

static uint FlushFileEntry(FileEntry* fe)
{
    uint ret = 0;
    FileEntry* feBase = ReadSector(fe->inSctIdx);
    FileEntry* feInSct = AddrOff(feBase, fe->inSctOff);

    *feInSct = *fe;

    ret = HDRawWrite(fe->inSctIdx, (byte*)feBase);

    Free(feBase);

    return ret;
}

static uint IsFDValid(FileDesc* fd)
{
    uint ret = 0;
    ListNode* pos = NULL;

    List_ForEach(&gFDList, pos)
    {
        if(IsEqual(pos, fd))
        {
            ret = 1;
            break;
        }
    }

    return ret;
}

static uint ToFlush(FileDesc* fd)
{
    return FlushCache(fd) && FlushFileEntry(&fd->fe);
}

void FClose(uint fd)
{
    FileDesc* pf = (FileDesc*)fd;

    if(IsFDValid(pf))
    {
        ToFlush(pf);

        List_DelNode((ListNode*)pf);

        Free(pf);
    }
}

static uint ReadToCache(FileDesc* fd, uint idx)
{
    uint ret = 0;

    if(idx < fd->fe.sctNum)
    {
        uint sctIdx = FindIndex(fd->fe.sctBegin, idx);

        ToFlush(fd);

        if( (sctIdx != SCT_END_FLAG) && (ret = HDRawRead(sctIdx, fd->cache)) )
        {
            fd->objIdx = idx;
            fd->offset = 0;
            fd->changed = 0;
        }
    }

    return ret;
}

static uint PrepareCache(FileDesc* fd, uint objIdx)
{
    CheckStorage(&fd->fe);

    return ReadToCache(fd, objIdx);
}

static uint CopyToCache(FileDesc* fd, byte* buf, uint len)
{
    uint ret = -1;

    if(fd->objIdx != SCT_END_FLAG)
    {
        uint n = SECT_SIZE - fd->offset;
        byte* p = AddrOff(fd->cache, fd->offset);

        n = (n < len) ? n : len;

        MemCpy(p, buf, n);

        fd->offset += n;
        fd->changed = 1;

        if( ((fd->fe.sctNum - 1) == fd->objIdx) && (fd->fe.lastBytes < fd->offset) )
        {
            fd->fe.lastBytes = fd->offset;
        }

        ret = n;
    }

    return ret;
}

static uint ToWrite(FileDesc* fd, byte* buf, uint len)
{
    uint ret = 1;
    uint i = 0;
    uint n = 0;

    while( (i < len) && ret )
    {
        byte* p = AddrOff(buf, i);
        if(fd->offset == SECT_SIZE)
        {
            ret = PrepareCache(fd, fd->objIdx + 1);
        }

        if(ret)
        {
            n = CopyToCache(fd, p, len - i);
            i += n;
        }
    }

    ret = i;

    return ret;
}

uint FWrite(uint fd, byte* buf, uint len)
{
    uint ret = -1;

    if(IsFDValid((FileDesc*)fd) && buf)
    {
        ret = ToWrite((FileDesc*)fd, buf, len);
    }

    return ret;
}

static uint CopyFromCache(FileDesc* fd, byte* buf, uint len)
{
    uint ret = (fd->objIdx != SCT_END_FLAG);

    if(ret)
    {
        uint n = SECT_SIZE - fd->offset;
        byte* p = AddrOff(fd->cache, fd->offset);

        n = (n < len) ? n : len;
        MemCpy(buf, p, n);

        fd->offset += n;

        ret = n;
    }

    return ret;
}

static uint GetFileLen(FileDesc* fd)
{
    uint ret = 0;

    if(fd->fe.sctBegin != SCT_END_FLAG)
    {
        ret = (fd->fe.sctNum - 1) * SECT_SIZE + fd->fe.lastBytes;
    }

    return ret;
}

static uint GetFilePos(FileDesc* fd)
{
    uint ret = 0;

    if( fd->fe.sctBegin != SCT_END_FLAG )
    {
        ret = (fd->fe.sctNum - 1) * SECT_SIZE + fd->offset;
    }

    return ret;
}

static uint ToRead(FileDesc* fd, byte* buf, uint len)
{
    uint ret = -1;
    uint n = GetFileLen(fd) - GetFilePos(fd);
    uint i = 0;

    len = (len < n) ? len : n;

    while ((i<len) && ret)
    {
        byte* p = AddrOff(buf, i);

        if(fd->offset == SECT_SIZE)
        {
            ret = PrepareCache(fd, fd->objIdx + 1);
        }
        if(ret)
        {
            n = CopyFromCache(fd, p, len - i);
        }

        i += n;
    }

    ret = i;
    
    return ret;
}

uint FRead(uint fd, byte* buf, uint len)
{
    uint ret = -1;

    if( IsFDValid((FileDesc*)fd) && buf )
    {
        ret = ToRead((FileDesc*)fd, buf, len);
    }

    return ret;
}

static uint ToLocate(FileDesc* fd, uint pos)
{
    uint ret = -1;
    uint len = GetFileLen(fd);

    pos = (pos < len) ? pos : len;

    uint objIdx = pos / SECT_SIZE;
    uint offset = pos % SECT_SIZE;
    uint sctIdx = FindIndex(fd->fe.sctBegin, objIdx);

    ToFlush(fd);

    if((sctIdx != SCT_END_FLAG) && HDRawRead(sctIdx, fd->offset))
    {
        fd->objIdx = objIdx;
        fd->offset = offset;

        ret = pos;
    }

    return ret;
}

uint FErase(uint fd, uint bytes)
{
    uint ret = 0;
    FileDesc* pf = (FileDesc*)fd;

    if( IsFDValid(pf) )
    {
        uint pos = GetFilePos(pf);
        uint len = GetFileLen(pf);

        ret = EraseLast((FSRoot*)(&pf->fe), bytes);

        len -= ret;

        if(ret && (pos > len))
        {
            ToLocate(pf, len);
        }
    }

    return ret;
}

uint FDelete(const char* fn)
{
    return fn && !IsOpened(fn) && DeleteInRoot(fn) ? FS_SUCCEED : FS_FAILED;
}

uint FSeek(uint fd, uint pos)
{
    uint ret = -1;
    FileDesc* pf = (FileDesc*)fd;

    if(IsFDValid(pf))
    {
        ret = ToLocate(pf, pos);
    }

    return ret;
}

uint FLength(uint fd)
{
    uint ret = -1;
    FileDesc* pf = (FileDesc*)fd;

    if( IsFDValid(pf) )
    {
        ret = GetFileLen(pf);
    }

    return ret;
}

uint FTell(uint fd)
{
    uint ret = -1;
    FileDesc* pf = (FileDesc*)fd;

    if( IsFDValid(pf) )
    {
        ret = GetFilePos(pf);
    }

    return ret;
}

uint FFlush(uint fd)
{
    uint ret = -1;
    FileDesc* pf = (FileDesc*)fd;

    if( IsFDValid(pf) )
    {
        ret = ToFlush(pf);
    }

    return ret;
}

uint FSIsFormatted()
{
    uint ret = 0;
    FSHeader* header = (FSHeader*)ReadSector(HEADER_SCT_IDX);
    FSRoot* root = (FSRoot*)ReadSector(ROOT_SCT_IDX);

    if(header && root)
    {
        ret = StrCmp(header->magic, FS_MAGIC, -1) &&
                (header->sctNum == HDRawSectors()) &&
                StrCmp(root->magic, ROOT_MAGIC, -1);
    }

    Free(header);
    Free(root);

    return ret;
}

uint FRename(const char* ofn, const char* nfn)
{
    uint ret = FS_FAILED;

    if(ofn && !IsOpened(ofn) && nfn)
    {
        FileEntry* ofe = FindInRoot(ofn);
        FileEntry* nfe = FindInRoot(nfn);

        if(ofe && !nfe)
        {
            StrCpy(ofe->name, nfn, sizeof(ofe->name) -1);

            if(FlushFileEntry(ofe))
            {
                ret = FS_SUCCEED;
            }
        }

        Free(ofe);
        Free(nfe);
    }

    return ret;
}

static char* GetFileNameInSector(FileEntry* feBase, char* files, uint cnt)
{
    char* ret = NULL;
    uint i = 0;

    for ( i = 0; i < cnt; i++)
    {
        FileEntry* fe = AddrOff(feBase, i);

        if (fe && fe->name && files)
        {
            ret = StrCat(files, fe->name);

            if(ret)
                ret = StrCat(files, "  " );
            else
                break;
        }
        else
        {
            Free(ret);
            ret = NULL;
        }
    }
    
    return ret;
}

char*  FileInDir(char* files)
{
    char* ret = NULL;
    FSRoot* root = (FSRoot*)ReadSector(ROOT_SCT_IDX);
    uint next = root->sctBegin;
    int i = 0;

    for(i = 0; i < (root->sctNum - 1); i++)
    {
        FileEntry* feBase = (FileEntry*)ReadSector(next);

        if(feBase)
        {
            ret = GetFileNameInSector(feBase, files, FE_ITEM_CNT);
        }
        Free(feBase);

        if(!ret)
        {
            next = NextSector(next);
        }
        else
        {
            break;
        }

    }

    if(!ret)
    {
        uint cnt = root->lastBytes / FE_BYTES;
        FileEntry* feBase = (FileEntry*)ReadSector(next);

        if(feBase)
        {
            ret = GetFileNameInSector(feBase, files, cnt);
        }

        Free(feBase);
    }

    PrintIntDec(StrLen(files));
    PrintChar('\n');

    return ret;
}