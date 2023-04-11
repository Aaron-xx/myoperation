#include <iostream>
#include <sstream>
#include "list.h"

using namespace std;

#define PAGE_NUM  (0xFF + 1)
#define FRAME_NUM (0x04)
#define FP_NONE   (-1)

struct FrameItem
{
	int pid;			// the task which use the frame
	int pnum;			// the page which the frame hold

	FrameItem()
	{
		pid = FP_NONE;
		pnum = FP_NONE;
	}
};

class PageTable
{
	int m_pt[PAGE_NUM];
	public:
	PageTable()
	{
		for(int i=0; i<PAGE_NUM; i++)
		{
			m_pt[i] = FP_NONE;
		}
	}

	int& operator[] (int i)
	{
		if( (0 <= i) && (i < length()) )
		{
			return m_pt[i];
		}
		else
		{
			exit(-1);
		}
	}

	int length()
	{
		return PAGE_NUM;
	}
};

class PCB 
{
	int m_pid;					// 任务的id
	PageTable m_pageTable;		// 任务的页表
	int* m_pageSerial;			// 模拟页的访问
	int m_pageSerialCount;		// 页的数量
	int m_next;					// 下一页

	public:
	PCB(int pid)
	{
		m_pid = pid;
		m_pageSerialCount = rand() % 5 + 5;
		m_pageSerial = new int [m_pageSerialCount];

		for(int i = 0; i < m_pageSerialCount; i++)
		{
			m_pageSerial[i] = rand() % 8;
		}
		m_next = 0;
	}

	int getPid()
	{
		return m_pid;
	}

	PageTable& getPageTable()
	{
		return m_pageTable;
	}
	int getNextPage()
	{
		int ret = m_next++;

		if(ret < m_pageSerialCount)
		{
			ret = m_pageSerial[ret];
		}
		else
		{
			ret = FP_NONE;
		}

		return ret;
	}

	bool running()
	{
		return (m_next < m_pageSerialCount);
	}

	void printPageSerial()
	{
		stringstream temp;
		string out = "";

		string s = "";
		for (int i = 0; i < m_pageSerialCount; i++)
		{
			s += m_pageSerial[i] + '0';
			s += ' ';
		}
		cout << "Task" <<  m_pid << " : " <<  s << endl;
	}
	~PCB()
	{
		delete[] m_pageSerial;
	}
};

FrameItem FrameTable[FRAME_NUM];
MyList<PCB*> TaskTable;

int Random();
int GetFrameItem();
void AccessPage(PCB& pcb);
int RequestPage(int pid, int page);
int SwapPage();
void PrintLog(string log);
void PrintPageMap(int pid, int page, int frame);
void PrintFatalError(string s, int pid, int page);

// 获取物理页框frame
int GetFrameItem()
{
	int ret = FP_NONE;

	for ( int i = 0; i < FRAME_NUM; i++)
	{
		if(FrameTable[i].pid == FP_NONE)
		{
			ret = i;
			break;
		}
	}
	return ret;
}

//先只进行任意次序的页换下
int Random()
{
	int obj = rand() % FRAME_NUM;
	PrintLog("Random select a frame to swap page content out: Frame" + to_string(obj));
    PrintLog("Write the selected page content back to disk.");

	FrameTable[obj].pid = FP_NONE;
	FrameTable[obj].pnum = FP_NONE;
	
	for (int i = 0,f = 0; (i < TaskTable.size()) && !f  ; i++)
	{
		PageTable& pt = TaskTable[i]->getPageTable();
		for (int j = 0; j < pt.length(); j++)
		{
			if(pt[j] == obj)
			{
				pt[j] = FP_NONE;
				f = 1;
			}
		}	
	}
	
	return obj;
}

int SwapPage()
{
	return Random();
}

//页请求
int RequestPage(int pid, int page)
{
	//获取页框
	int frame = GetFrameItem();

	if(frame != FP_NONE)
	{
		PrintLog("Get a frame to hold page content: Frame" + to_string(frame));
	}
	else
	{
		//若没有获取到，进行页交换
		frame = SwapPage();

		if(frame != FP_NONE)
		{
			PrintLog("Succeed to swap lazy page out.");
		}
		else
		{
			PrintFatalError("Failed to swap page out.", pid, FP_NONE);
		}
	}

	PrintLog("Load content from disk to Frame" + to_string(frame));
	// 页交换成功后将pid和页号填充到换下的页框中
	FrameTable[frame].pid = pid;
	FrameTable[frame].pnum = page;

	return frame;
}

// 页访问
void AccessPage(PCB& pcb)
{
	int pid = pcb.getPid();
	PageTable& pageTable = pcb.getPageTable();
	int page  = pcb.getNextPage();

	if(page != FP_NONE)
	{
		PrintLog("Access Task" + to_string(pid) + " for Page" + to_string(page));

		if(pageTable[page] != FP_NONE)
		{
			PrintLog("Find target page in page table");
			PrintPageMap(pid,page,pageTable[page]);
		}
		else
		{
			// 访问的页不在，进行页请求
			PrintLog("Target page is NOT found, need to request page ...");
			pageTable[page]  = RequestPage(pid,page);

			if(pageTable[page] != FP_NONE)
			{
				PrintPageMap(pid,page,pageTable[page]);
			}
			else
			{
				PrintFatalError("Can NOT request page from disk...", pid, page);
			}
		}
	}
	else
	{
		PrintLog("Task" + to_string(pid) + " is finished!");
	}
}
void PrintLog(string log)
{
	cout << log << endl;
}
void PrintPageMap(int pid, int page, int frame)
{
	string s = "Task" + to_string(pid) + " : ";
	s = "Page" + to_string(page) + " ===> Frame" + to_string(frame);
	cout << s << endl;
}
void PrintFatalError(string s, int pid, int page)
{
	s = "Page" + to_string(pid) + ": Page" + to_string(page);
	cout << s << endl;
	exit(-2);
}

int main()
{
	int index = 0;

	TaskTable.append(new PCB(1));
	TaskTable.append(new PCB(2));
	TaskTable.append(new PCB(3));

	for(int i=0; i<TaskTable.size(); i++)
	{
		TaskTable[i]->printPageSerial();
	}

	while (true)
	{
		if(TaskTable[index]->running())
		{
			AccessPage(*TaskTable[index]);
		}
		index = (index + 1) % TaskTable.size();

		cin.get();
	}
	return 0;
}
