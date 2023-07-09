#include <iostream>
#include "list.h"
#include "queue.h"

using namespace std;

#define PAGE_DIR_NUM  (0xF + 1)	// 一级页表
#define PAGE_SUB_NUM  (0xF + 1)	// 子页表
#define PAGE_NUM  (PAGE_DIR_NUM * PAGE_SUB_NUM)
#define FRAME_NUM (0x04)
#define FP_NONE   (-1)

struct FrameItem
{
	int pid;			// 使用该页框的任务pid
	int pnum;			// 页框内的页面号
	int ticks;			// 该页框的使用频率

	FrameItem()
	{
		pid = FP_NONE;
		pnum = FP_NONE;
		ticks = 0xFF;
	}
};

class PageTable
{
	int* m_pt[PAGE_DIR_NUM];
public:
	PageTable()
	{
		for(int i=0; i<PAGE_DIR_NUM; i++)
		{
			m_pt[i] = NULL;
		}
	}

	int& operator[] (int i)
	{
		if( (0 <= i) && (i < length()) )
		{
			int dir = ((i & 0xF0) >> 4);
			int sub = (i & 0x0F);

			// 为减少空页对内存的的浪费，只有当访问到某页时，才会申请内存
			if(m_pt[dir] == NULL)
			{
				m_pt[dir] = new int[PAGE_SUB_NUM];

				for (int j = 0; j < PAGE_SUB_NUM; j++)
				{
					m_pt[dir][j] = FP_NONE;
				}
			}
			return m_pt[dir][sub];
		}
		else
		{
			exit(-1);
			return m_pt[0][0];	// 返回值不能为空
		}
	}

	int length()
	{
		return PAGE_NUM;
	}

	~PageTable()
	{
		for(int i=0; i<PAGE_DIR_NUM; i++)
		{
			delete m_pt[i];
		}
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
MyQueue<int> TaskQueue;

int Random();
int GetFrameItem();
void AccessPage(PCB& pcb);
int RequestPage(int pid, int page);
int SwapPage();
int Random();
int FIFO();
int LRU();
void ClearFrameItem(PCB& pcb);
void ClearFrameItem(int frame);
void PrintLog(string log);
void PrintPageMap(int pid, int page, int frame);
void PrintFatalError(string s, int pid, int page);

void ClearFrameItem(PCB& pcb)
{
	for (int i = 0; i < FRAME_NUM; i++)
	{
		if(FrameTable[i].pid == pcb.getPid())
		{
			FrameTable[i].pid = FP_NONE;
			FrameTable[i].pnum = FP_NONE;
		}
	}
}

void ClearFrameItem(int frame)
{
	for (int i = 0; i < FRAME_NUM; i++)
	{
		if(FrameTable[i].pid == frame)
		{
			FrameTable[i].pid = FP_NONE;
			FrameTable[i].pnum = FP_NONE;
		}
	}
}

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

// 先进队列者先出
int FIFO()
{
	// 列表头出队列
	int obj = TaskQueue.dequeue();

	PrintLog("Select a frame to swap page content out: Frame" + to_string(obj));
    PrintLog("Write the selected page content back to disk.");

	ClearFrameItem(obj);

	return obj;
}

// 使用次数最少的页被换下
int LRU()
{
	int obj = 0;
	int ticks = FrameTable[obj].ticks;
	string s = "";

	// 取出ticks最小的frame
	for (int i = 0; i < FRAME_NUM; i++)
	{
		s += "Frame" + to_string(i) + " : " + to_string(FrameTable[i].ticks) + "    ";
		
		if(ticks > FrameTable[i].ticks)
		{
			ticks = FrameTable[i].ticks;
			obj = i;
		}
	}
	PrintLog(s);
	PrintLog("Select the LRU frame page to swap content out: Frame" + to_string(obj));
	PrintLog("Write the selected page content back to disk.");

	ClearFrameItem(obj);

	return obj;
}


int SwapPage()
{
	//return Random();
	//return FIFO();
	return LRU();
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
	FrameTable[frame].ticks = 0xFF;

	// 将请求到的页加入队列
	TaskQueue.enqueue(frame);

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
				exit(-1);
			}
		}
		FrameTable[pageTable[page]].ticks++;
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
	//TaskTable.append(new PCB(3));

	for(int i=0; i<TaskTable.size(); i++)
	{
		TaskTable[i]->printPageSerial();
	}
	
	while (true)
	{
		for (int i = 0; i < FRAME_NUM; i++)
		{
			FrameTable[i].ticks--;
		}
		
		if (TaskTable.size() > 0)
		{
			if(TaskTable[index]->running())
			{
				AccessPage(*TaskTable[index]);
			}
			else
			{
				PrintLog("Task" + to_string(TaskTable[index]->getPid()) + " is finished!");
				PCB* pcb = TaskTable[index];
				TaskTable.removeAt(index);
				ClearFrameItem(*pcb);

				delete pcb;
			}
		}

		if(TaskTable.size() > 0)
		{
			index = (index + 1) % TaskTable.size();
		}
		else
		{
			break;
		}

		//cin.get();
	}
	return 0;
}
