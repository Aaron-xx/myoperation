#include <iostream>
#include <list>

using namespace std;

template <typename T>
class MyQueue {
private:
    list<T> m_data; 
public:
    MyQueue() {}

    void enqueue(const T& value) 
    {
        m_data.push_back(value);
    }

    int dequeue() 
    {
        int ret = -1;
        if (!isEmpty()) 
        {
            m_data.pop_front();
            ret = m_data.front();
        } 
        else 
        {
            cout << "Error: queue is empty." << endl;
        }
        return ret;
    }

    const T& front() const 
    {
        if (!isEmpty()) 
        {
            return m_data.front();
        } 
        else 
        {
            cout << "Error: queue is empty." << endl;
            static T defaultValue;
            return defaultValue;
        }
    }

    int size() const 
    {
        return m_data.size();
    }

    bool isEmpty() const 
    {
        return m_data.empty();
    }

    ~MyQueue() {}
};
