template<class T>
class MyList
{
private:
    T* m_data;              // 数组指针
    int m_size;             // 元素个数
    int m_capacity;         // 数组容量

public:
    // 构造函数
    MyList() 
        : m_data(nullptr), m_size(0), m_capacity(0) 
    {}

    // 添加元素
    void append(const T& value)
    {
        if (m_size >= m_capacity)
        {
            // 扩容
            reserve(m_capacity == 0 ? 1 : m_capacity * 2);
        }
        m_data[m_size++] = value;
    }

    // 获取元素个数
    int size() const 
    {
        return m_size;
    }

    // 获取元素
    T& operator[](int index)
    {
        return m_data[index];
    }

private:
    // 扩容
    void reserve(int newCapacity)
    {
        // 分配新的内存
        T* newData = new T[newCapacity];
        // 复制原始数据
        for (int i = 0; i < m_size; ++i)
        {
            newData[i] = m_data[i];
        }
        // 释放原有内存
        delete[] m_data;
        // 更新容量和指针
        m_data = newData;
        m_capacity = newCapacity;
    }
public:
    // 释放内存
    ~MyList()
    {
        delete[] m_data;
    }
};

