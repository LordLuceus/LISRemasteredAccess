#include "movie_time.h"
#include <vector>
#include <iostream>
#include <stdexcept>
struct Memory {
    static constexpr uintptr_t base = 0x100000000ULL;
    std::vector<unsigned char> bytes = std::vector<unsigned char>(0x3700000);
    bool operator()(uintptr_t p, void* out, size_t n) {
        if (p < base || p-base > bytes.size() || n > bytes.size()-(p-base)) return false;
        std::memcpy(out, bytes.data()+(p-base), n); return true;
    }
    template<class T> void put(uintptr_t rva, T value) { std::memcpy(bytes.data()+rva, &value, sizeof(value)); }
    Memory() {
        put<int>(0x35a391c, 3); put<uintptr_t>(0x35a3908, base+0x800); put<uintptr_t>(0x800, base+0x1000);
        for (int i=1; i<=2; ++i) {
            put<uintptr_t>(0x1000+i*24, base+uintptr_t(i)*0x2000);
            put<int>(uintptr_t(i)*0x2000+12, i); // deliberately zero weak serial
        }
        put<uintptr_t>(0x2010,base+0x4000); put<uintptr_t>(lisr::movie::class_rva,base+0x4000);
        put<uintptr_t>(0x2110,base+0x6000);
        std::memcpy(bytes.data()+lisr::movie::getter_rva,lisr::movie::getter_bytes,sizeof(lisr::movie::getter_bytes));
    }
};
void require(bool b) { if (!b) throw std::runtime_error("movie clock assertion"); }
int main() {
    try {
        Memory m; bool module=true, success=true; int calls=0; int64_t ticks=123456789;
        auto sample=[&] { return lisr::movie::sample(m,Memory::base,module,Memory::base+0x2000,Memory::base+0x4000,
            [&](uintptr_t fn,uintptr_t p,int64_t& out) { ++calls; require(fn==Memory::base+lisr::movie::getter_rva && p==Memory::base+0x2000); out=ticks; return success; }); };
        auto is=[&](const char* status) { require(std::strcmp(sample().status,status)==0); };
        is("ok"); require(std::abs(sample().seconds-12.3456789)<1e-12);
        ticks=0; is("ok"); ticks=INT64_MAX; require(std::isfinite(sample().seconds)); ticks=-1; is("clock"); ticks=1;
        success=false; is("getter"); success=true;
        int before=calls; module=false; is("module"); module=true;
        m.bytes[lisr::movie::getter_rva]^=1; is("signature"); m.bytes[lisr::movie::getter_rva]^=1;
        m.put<uintptr_t>(lisr::movie::class_rva,0); is("class"); m.put<uintptr_t>(lisr::movie::class_rva,Memory::base+0x4000);
        m.put<uintptr_t>(0x2010,Memory::base+0x2000); is("class"); m.put<uintptr_t>(0x2010,Memory::base+0x4000);
        m.put<int>(0x200c,99); is("object"); m.put<int>(0x200c,1);
        m.put<uint32_t>(0x2008,0x8000); is("object"); m.put<uint32_t>(0x2008,0);
        m.put<uint32_t>(0x1000+24+8,0x20000000); is("object"); m.put<uint32_t>(0x1000+24+8,0);
        m.put<uintptr_t>(0x1000+24,0); is("object"); m.put<uintptr_t>(0x1000+24,Memory::base+0x2000);
        m.put<uintptr_t>(0x2110,0); is("facade"); require(calls==before);
        std::cout << "movie clock checks passed\n"; return 0;
    } catch(const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
