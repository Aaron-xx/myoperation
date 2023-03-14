#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int uint;
typedef unsigned short ushort;
typedef unsigned char uchar;

#pragma pack(push)	// 将当前的对齐方式保存到堆栈
#pragma pack(1)		// 按照字节对齐

struct Fat12Header
{
    char BS_OEMName[8];		// OEM 字符串，长度为 8 个字节，表示格式化该磁盘的操作系统的名称
    ushort BPB_BytsPerSec;	// 每个扇区的字节数
    uchar BPB_SecPerClus;	// 每个簇的扇区数
    ushort BPB_RsvdSecCnt;	// 保留扇区数，包括引导扇区和文件系统信息扇区
    uchar BPB_NumFATs;		// FAT 表的个数
    ushort BPB_RootEntCnt;	// 根目录区域所占用的条目数
    ushort BPB_TotSec16;	// FAT32 之前使用的字段，表示总扇区数（16 位）
    uchar BPB_Media;		// 介质描述符，指定介质类型
    ushort BPB_FATSz16;		// FAT 表的扇区数（16 位）
    ushort BPB_SecPerTrk;	// 每个磁道的扇区数
    ushort BPB_NumHeads;	// 磁头数
    uint BPB_HiddSec;		// 隐藏扇区数
    uint BPB_TotSec32;		// FAT32 使用的字段，表示总扇区数（32 位）
    uchar BS_DrvNum;		// 驱动器编号
    uchar BS_Reserved1;		// 保留字段
    uchar BS_BootSig;		// 扩展引导标志，指示是否有扩展引导记录
    uint BS_VolID;			// 卷序列号，用于标识卷
    char BS_VolLab[11];		// 卷标，长度为 11 个字节，用于标识卷
    char BS_FileSysType[8];	// 文件系统类型，长度为 8 个字节，表示文件系统的类型
};

struct RootEntry
{
    char DIR_Name[11];		// 文件或目录的名称
    uchar DIR_Attr;			// 文件或目录的属性
    uchar reserve[10];		// 保留空间
    ushort DIR_WrtTime;		// 文件或目录的最后一次写入时间
    ushort DIR_WrtDate;		// 文件或目录的最后一次写入日期
    ushort DIR_FstClus;		// 文件或目录的第一个簇的编号
    uint DIR_FileSize;		// 文件大小
};

#pragma pack(pop)	//回复之前的对齐方式

char *strdup(const char *s)
{
    size_t len = strlen(s) + 1;
    char *p = malloc(len);
    if (p != NULL) {
        memcpy(p, s, len);
    }
    return p;
}

void trimmed(char* str)
{
    int i = 0, j = 0;

    // 删除空格
    while (str[i] != '\0')
    {
        if (str[i] != ' ')
        {
            str[j++] = str[i];
        }
        i++;
    }

    str[j] = '\0';
}

//查找根目录中第i个文件的文件入口
struct RootEntry findRootEntry(struct Fat12Header* rf, char* pimg, int i)
{
	struct RootEntry ret = {{0}};
	FILE *fp;
	
	if((fp = fopen(pimg,"r")) && (i >= 0) && (i < rf->BPB_RootEntCnt))
	{
			//将光标设置到pos处
			long pos = 19 * rf->BPB_BytsPerSec + i * sizeof(struct RootEntry);
			fseek(fp, pos, SEEK_SET);
			
			//读取指定位置读取一个文件目录
			fread(&ret, 1, sizeof(struct RootEntry), fp);

	}
	
	fclose(fp);
	
	return ret;
}

//查找指定文件名的头信息
struct RootEntry FindRootEntry(struct Fat12Header* rf, char* pimg, char* fn)
{
    struct RootEntry ret = {{0}};

    for(int i=0; i<rf->BPB_RootEntCnt; i++)
    {
        struct RootEntry re = findRootEntry(rf, pimg, i);

        if( re.DIR_Name[0] != '\0' )
        {
			char *findName = strdup(re.DIR_Name);
			char* fileName = strdup(fn);
			if(fileName == NULL)
			{
				printf("Memory request failed\n");
				return re;
			}
			trimmed(fileName);
			trimmed(findName);
			
			//分析并处理需要寻找的的文件名
			char *p = strchr(fileName, '.');
			int d = p - fileName;
				
			//d>=0则有后缀名，否则没有
            if( d >= 0 && strstr(fileName,"."))
            {
				if(findName == NULL)
				{
					printf("Memory request failed\n");
					return re;
				}
				trimmed(findName);
				
				//分割需要寻找的的文件名中的前后缀
				char *prefix = strtok(fileName, ".");
				char *suffix = strtok(NULL, ".");
				
				//判断当前根目录文件名前缀是否为寻找字串前缀
                if(!(strncmp(findName, prefix, strlen(prefix)))  \
					//判断当前根目录文件名后缀是否为寻找字串后缀
					&& !(strcmp(suffix, findName + (strlen(findName) - strlen(suffix)))))
                {
                    ret = re;
                    break;
                }
                
                free(fileName);
				free(findName);
            }
            else
            {
                if( !strcmp(findName,fileName) )
                {
                    ret = re;
                    break;
                }
            }
        }
    }
    return ret;
}

void printRootEntry(struct Fat12Header* rf, char* p)
{
	//判断文件名是否为空
	if(p == NULL)
	{
		printf("fileName: rull error\n");
		exit(-1);
	}
	//printf("%d\n",rf->BPB_RootEntCnt);
	//打印并遍历所有文件及文件夹
	for(int i = 0 ;i < rf->BPB_RootEntCnt ;i++)
	{
		struct RootEntry re = findRootEntry(rf, p, i);

		//打印每个文件信息
		if(re.DIR_Name[0] != 0)
		{
			printf("%d:\n",i);
			printf("DIR_Name: %s\n",re.DIR_Name);
			printf("DIR_Attr: %hhu\n",re.DIR_Attr);
			printf("DIR_WrtDate: %hhu\n",re.DIR_WrtDate);
			printf("DIR_WrtTime: %hu\n",re.DIR_WrtTime);
			printf("DIR_FstClus: %hu\n",re.DIR_FstClus);
			printf("DIR_FileSize: %u\n",re.DIR_FileSize);
		}
	}
	
}

void printHeader(struct Fat12Header* rf, char* p)
{
	//printf("%s\n",p);
	//判断文件名是否为空
	if(p == NULL)
	{
		printf("fileName: rull error\n");
		exit (-1);
	}

	FILE *fp;
	//以只读方式打开文件
	if(fp = fopen(p,"rb"))
	{
		//FAT12 文件系统的头部信息通常存储在引导扇区后面的第 3 个字节处
		fseek(fp, 3, SEEK_SET);  
		
		//读取Fat12头信息
		fread(rf, 1, sizeof(struct Fat12Header), fp);

		//作为字符串打印，所以末尾设置为0
		//rf->BS_OEMName[7]=0;
		rf->BS_VolLab[10] = 0;
        	rf->BS_FileSysType[7] = 0;

		printf("BS_OEMName：%s\n",rf->BS_OEMName);
		printf("BPB_BytsPerSec: %hu\n",rf->BPB_BytsPerSec);
		printf("BPB_SecPerClus: %hhu\n",rf->BPB_SecPerClus);
		printf("BPB_RsvdSecCnt: %hu\n",rf->BPB_RsvdSecCnt);
		printf("BPB_NumFATs: %hhu\n",rf->BPB_NumFATs);
		printf("BPB_RootEntCnt: %hu\n",rf->BPB_RootEntCnt);
		printf("BPB_TotSec16: %hu\n",rf->BPB_TotSec16);
		printf("BPB_Media: %hhu\n",rf->BPB_Media);
		printf("BPB_FATSz16: %hu\n",rf->BPB_FATSz16);
		printf("BPB_SecPerTrk: %hu\n",rf->BPB_SecPerTrk);
		printf("BPB_NumHeads: %hu\n",rf->BPB_NumHeads);
		printf("BPB_HiddSec: %u\n",rf->BPB_HiddSec);
		printf("BPB_TotSec32: %u\n",rf->BPB_TotSec32);
		printf("BS_DrvNum: %hhu\n",rf->BS_DrvNum);
		printf("BS_Reserved1: %hhu\n",rf->BS_Reserved1);
		printf("BS_BootSig: %hhu\n",rf->BS_BootSig);
		printf("BS_VolID: %u\n",rf->BS_VolID);
		printf("BS_VolLab: %s\n",rf->BS_VolLab);
		printf("BS_FileSysType: %s\n",rf->BS_FileSysType);
		
	}
	else
	{
		printf("header message fail\n");
		exit(-2);

	}

	fclose(fp);
}

ushort* ReadFat(struct Fat12Header* rf, char* pimg)
{
	FILE* fp;

	int fatTabSize = rf->BPB_BytsPerSec * 9;
	char* fat = (uchar*)malloc(fatTabSize);
	ushort* ret = (ushort*)malloc((fatTabSize * 2 / 3) * sizeof(ushort));
	memset(ret, 0xFF, (fatTabSize * 2 / 3) * sizeof(ushort));
	
	if(fp = fopen(pimg,"r"))
	{
			//将光标设置到Fat表入口处
			long pos = 1 * rf->BPB_BytsPerSec;
			fseek(fp, pos, SEEK_SET);
			
			//在指定位置读取一个Fat表项
			fread(fat, 1, fatTabSize, fp);
			
			for(int i,j=0; i<fatTabSize; i+=3,j+=2)
			{
				//每个Fat表项占1.5个字节，所以每2个Fat表项j使用3个字节
				ret[j] = (ushort) (((fat[i+1] & 0x0F) << 8) | fat[i]);
				ret[j+1] = (ushort) ((fat[i+2] << 4) | ((fat[i+1] >> 4) & 0x0F));
			}
	}
	
	fclose(fp);
	
	free(fat);
	
	return ret;
}

char* ReadFileContent(struct Fat12Header* rf, char* pimg, char* fn)
{
	FILE* fp;
	char* ret;
	struct RootEntry re;
	
	//找到指定的文件fn目录项
	re = FindRootEntry (rf,pimg,fn);
	
	if(re.DIR_Name[0] != '\0')
	{
		//寻找Fat表项
		ushort* fat = ReadFat(rf,pimg);
		
		//count每读到一个字节自增1,标记已读取到的字节数
		int count = 0;
		if(fp = fopen(pimg,"r"))
		{
			ret = (char*) malloc(re.DIR_FileSize);
			if(ret == NULL) 
			{
				fclose(fp);
				return NULL;
			}
			char buf[512] = {0};
			
			for(int i = 0,j=re.DIR_FstClus;j < 0xFF7; i+=512, j=fat[j])
			{
				//将位置设置为fat表对应的的数据处
				long pos = rf->BPB_BytsPerSec * (31 + j);
				fseek(fp, pos, SEEK_SET);
				
				//读取文件内容
				//一次读取一个扇区到缓存中
				fread(buf, 1, sizeof(buf), fp);
				
				//将缓存中数据组成文件内容放入内存
				for(uint k = 0;k < sizeof(buf);k++)
				{
					
					if(count < re.DIR_FileSize)
					{
						ret[i+k] = buf[k];
						count++;
					}
				}
				memset(buf,0,sizeof(buf));
			}
		}
		free(fat);
	}
	fclose(fp);
	
	return ret;
}

int main()
{
	struct Fat12Header* Fat12 = (struct Fat12Header*) malloc (sizeof (struct Fat12Header)) ;
	char tfile[] = "data.img";

	printf("======Fat12HeaderEntry=====\n");

	printHeader(Fat12,tfile);
	
	printf("======RootEntry=====\n");
	
	printRootEntry(Fat12,tfile);
	
	char* con = ReadFileContent(Fat12,tfile,"LOADER     ");
	printf("======load Loader=====\n");
	//if(!con)
		printf("%s\n",con);
}
