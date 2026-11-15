#include "rewind_snapshot.h"
#include <vector>
#include <cstring>
#include <iostream>
#include <stdexcept>
struct Memory {
    static constexpr uintptr_t base = 0x100000000ULL;
    std::vector<unsigned char> bytes = std::vector<unsigned char>(0x3600000);
    uintptr_t fault = 0;
    bool operator()(uintptr_t p, void* out, size_t n) {
        if (p < base || p-base > bytes.size() || n > bytes.size()-(p-base) || (fault >= p && fault < p+n)) return false;
        std::memcpy(out, bytes.data()+(p-base), n); return true;
    }
    template<class T> void put(uintptr_t rva, T value) { std::memcpy(bytes.data()+rva, &value, sizeof(value)); }
    void object(int index, uintptr_t rva, uintptr_t klass = 0) {
        put<uintptr_t>(0x1000 + uintptr_t(index)*24, base+rva);
        put<int>(0x1000 + uintptr_t(index)*24+16, 100+index);
        put<int>(rva+12, index); put<uintptr_t>(rva+16, base+klass);
    }
    Memory() {
        put<int>(0x35a391c, 16); put<uintptr_t>(0x35a3908, base+0x800); put<uintptr_t>(0x800, base+0x1000);
        object(1,0x2000,0x3000); object(2,0x3000); object(3,0x4000); object(4,0x5000,0x4000);
        put<uintptr_t>(0x35505a0, base+0x3000); put<uintptr_t>(0x3550640, base+0x4000);
        put<lisr::rewind::Weak>(0x33dfdd0, {1,101});
        put<uint8_t>(0x20c8,1); put<float>(0x2098,8); put<float>(0x212c,10); put<float>(0x2138,20);
        put<uintptr_t>(0x20e0,base+0x5000); put<uintptr_t>(0x5020,base+0x2000); put<float>(0x5028,7);
    }
};
void require(bool b) { if (!b) throw std::runtime_error("rewind snapshot assertion"); }
int main() {
    try {
        Memory m; auto sample=[&] { return lisr::rewind::Reader(m, Memory::base).sample(); };
        auto s=sample(); require(s.status==0 && s.state==1 && s.index==1 && s.serial==101 && s.marker_known && s.marker_present && s.marker_time==7 && s.range==10 && !s.visibility_known);
        m.put<uint8_t>(0x211e,1); require(sample().range==20); m.put<uint8_t>(0x211e,0);
        m.put<uintptr_t>(0x20e0,0); s=sample(); require(s.status==0 && s.marker_known && !s.marker_present);
        m.put<uintptr_t>(0x20e0,Memory::base+0x5000);
        m.put<uintptr_t>(0x5020,Memory::base+0x3000); require(!sample().marker_known); m.put<uintptr_t>(0x5020,Memory::base+0x2000);
        m.put<int>(0x1000+4*24+16,0); require(sample().marker_known); m.put<int>(0x1000+4*24+16,104);
        m.put<int>(0x1000+2*24+16,0); m.put<int>(0x1000+3*24+16,0);
        require(sample().status==0 && sample().marker_known); // classes without allocated weak serials
        m.put<int>(0x1000+2*24+16,102); m.put<int>(0x1000+3*24+16,103);
        // The actual singleton remains a strict weak handle, unlike marker/class pointers.
        m.put<lisr::rewind::Weak>(0x33dfdd0,{1,0}); require(sample().status==1);
        m.put<lisr::rewind::Weak>(0x33dfdd0,{1,101});
        m.put<uint32_t>(0x1000+4*24+8,0x20000000); require(!sample().marker_known); m.put<uint32_t>(0x1000+4*24+8,0);
        m.put<uintptr_t>(0x5010,Memory::base+0x3000); require(!sample().marker_known); m.put<uintptr_t>(0x5010,Memory::base+0x4000);
        m.fault=Memory::base+0x5028; require(!sample().marker_known); m.fault=0;
        m.put<float>(0x5028,std::numeric_limits<float>::quiet_NaN()); require(!sample().marker_known); m.put<float>(0x5028,7);
        m.put<lisr::rewind::Weak>(0x33dfdd0,{1,102}); require(sample().status==1); m.put<lisr::rewind::Weak>(0x33dfdd0,{1,101});
        m.put<uint32_t>(0x2008,0x10); require(sample().status==1); m.put<uint32_t>(0x2008,0);
        m.put<uint32_t>(0x1000+24+8,0x10000000); require(sample().status==1); m.put<uint32_t>(0x1000+24+8,0);
        m.object(5,0x6000);m.object(6,0x7000);m.object(7,0x8000,0x7000);m.object(8,0x9000);
        m.put<lisr::rewind::Weak>(0x3312708,{5,105});m.put<uintptr_t>(0x3550718,Memory::base+0x7000);
        m.put<uintptr_t>(0x60a0,Memory::base+0xa000);m.put<int>(0x60a8,1);m.put<uintptr_t>(0xa000,Memory::base+0x8000);
        m.put<uint8_t>(0x8271,8);m.put<uint8_t>(0x8270,1);m.put<uintptr_t>(0x2130,Memory::base+0x9000);
        s=sample();require(s.writer_gate_known && s.writer_gate && s.writer_widget==Memory::base+0x8000 && s.writer_material==Memory::base+0x9000);
        require(!s.visibility_known && !s.visible); // native prerequisite is not Slate visibility
        m.put<uint8_t>(0x8270,0);require(sample().writer_gate_known && !sample().writer_gate);m.put<uint8_t>(0x8270,1);
        m.put<uint8_t>(0x8271,9);require(!sample().writer_gate);m.put<uint8_t>(0x8271,8);
        m.put<int>(0x1000+8*24+16,0);require(sample().writer_gate); // raw material can have no weak handle
        m.put<uint32_t>(0x9008,0x8000);require(!sample().writer_gate);m.put<uint32_t>(0x9008,0);
        m.put<uint8_t>(0x20c8,5); require(sample().status==2); m.put<uint8_t>(0x20c8,1);
        m.put<float>(0x212c,0); require(sample().status==3); m.put<float>(0x212c,10);
        m.put<float>(0x2098,std::numeric_limits<float>::infinity()); require(sample().status==3);
        std::cout << "rewind snapshot checks passed\n"; return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
