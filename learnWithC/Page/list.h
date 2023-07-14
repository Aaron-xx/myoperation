#include <iostream>
#include <vector>
using namespace std;
template <typename T>
class MyList 
{
private:
    vector<T> m_data;
public:
    MyList() {}

    void append(const T& value) 
    {
        m_data.push_back(value);
    }

    void insert(int index, const T& value) 
    {
        if (index >= 0 && index <= size()) 
        {
            m_data.insert(m_data.begin() + index, value);
        } 
        else 
        {
            cout << "Error: index out of range." << endl;
        }
    }

    void removeAt(int index) {
        if (index >= 0 && index < size()) 
        {
            m_data.erase(m_data.begin() + index);
        } 
        else 
        {
            cout << "Error: index out of range." << endl;
        }
    }

    void removeAll(const T& value) {
        for (auto iter = m_data.begin(); iter != m_data.end(); ) 
        {
            if (*iter == value) 
            {
                iter = m_data.erase(iter);
            } 
            else 
            {
                ++iter;
            }
        }
    }

    void clear() {
        m_data.clear();
    }

    int indexOf(const T& value) const {
        int index = -1;
        for (int i = 0; i < size(); ++i) 
        {
            if (m_data[i] == value) 
            {
                index = i;
                break;
            }
        }
        return index;
    }

    bool contains(const T& value) const 
    {
        return indexOf(value) != -1;
    }

    T& operator[](int index) 
    {
        return m_data[index];
    }

    const T& operator[](int index) const 
    {
        return m_data[index];
    }

    int size() const 
    {
        return m_data.size();
    }

    bool isEmpty() const 
    {
        return m_data.empty();
    }
    ~MyList() {}
};

