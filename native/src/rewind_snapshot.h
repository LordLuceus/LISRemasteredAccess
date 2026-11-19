#pragma once
#include <cstdint>
#include <cmath>
#include <limits>

namespace lisr::rewind {
namespace pinned {
// RIP-relative targets independently checked against recorded c141ab07
// instructions by tests/test_rewind_addresses.py; not decimal transcription.
inline constexpr uintptr_t manager_class = 0x35505a0;
inline constexpr uintptr_t marker_class = 0x3550640;
inline constexpr uintptr_t widget_class = 0x3550718;
inline constexpr uintptr_t manager_weak = 0x33dfdd0;
inline constexpr uintptr_t widget_manager_weak = 0x3312708;
inline constexpr uintptr_t object_count = 0x35a391c;
inline constexpr uintptr_t object_chunks = 0x35a3908;
}
// Pinned c141ab07... executable only. No engine calls, object creation or writes.
struct Snapshot {
    int status = 1; // 0 ready, 1 acquisition failure, 2 invalid state, 3 invalid timeline
    int index = -1, serial = 0, state = -1;
    float reference = 0, range = 0, marker_time = 0;
    bool marker_known = false, marker_present = false;
    bool writer_gate_known = false, writer_gate = false;
    // OpeningState is NOT proven actual Slate visibility. Do not claim otherwise.
    bool visibility_known = false, visible = false;
    uintptr_t writer_widget = 0, writer_material = 0; // same-sample identity only
};
struct Weak { int32_t index, serial; };
static_assert(sizeof(Weak) == 8);

template<class Memory> class Reader {
    Memory& memory;
    uintptr_t base;
    template<class T> bool get(uintptr_t p, T& v) {
        if (!p || p > std::numeric_limits<uintptr_t>::max() - sizeof(T)) return false;
        return memory(p, &v, sizeof(T));
    }
    bool item(int index, uintptr_t& address) {
        int count{}; uintptr_t chunks{}, chunk{};
        if (!get(base + pinned::object_count, count) || index < 0 || index >= count || count > 16000000 ||
            !get(base + pinned::object_chunks, chunks) || !chunks ||
            !get(chunks + uintptr_t(index / 65536) * 8, chunk) || !chunk) return false;
        address = chunk + uintptr_t(index % 65536) * 24;
        return true;
    }
    bool resolve(Weak w, uintptr_t& object) {
        uintptr_t entry{}; int serial{}; uint32_t flags{};
        return w.serial > 0 && item(w.index, entry) && get(entry + 16, serial) && serial == w.serial &&
            get(entry + 8, flags) && !(flags & 0x30000000u) && get(entry, object) && object;
    }
    bool valid(uintptr_t object, Weak* identity = nullptr) {
        int index{}, serial{}; uintptr_t entry{}, resolved{}; uint32_t flags{};
        // A weak handle requires a nonzero serial. An ordinary live UObject
        // need not have had a weak serial allocated: check its current slot,
        // flags and identity directly, not by manufacturing a weak handle.
        uint32_t internal_flags{};
        if (!get(object + 12, index) || !item(index, entry) || !get(entry + 16, serial) || serial < 0 ||
            !get(entry, resolved) || resolved != object || !get(entry + 8, internal_flags) ||
            (internal_flags & 0x30000000u) || !get(object + 8, flags) ||
            (flags & 0x00058030u)) return false; // CDO/archetype/default-subobject/begin+finish destroy
        if (identity) *identity = {index, serial};
        return true;
    }
    bool class_at(uintptr_t rva, uintptr_t& klass) {
        return get(base + rva, klass) && klass && valid(klass);
    }
    bool still_current(Weak before, uintptr_t manager) {
        Weak after{}; uintptr_t current{};
        return get(base + pinned::manager_weak, after) && after.index == before.index && after.serial == before.serial &&
            resolve(after, current) && current == manager && valid(manager);
    }
    bool is_a(uintptr_t object, uintptr_t expected) {
        uintptr_t actual{}, chain{}, entry{}; int index{}, count{};
        if (!valid(object) || !get(object + 16, actual) || !valid(actual)) return false;
        if (actual == expected) return true;
        return get(expected + 0x38, index) && index >= 0 && index < 128 &&
            get(actual + 0x38, count) && count >= index && count < 128 &&
            get(actual + 0x30, chain) && chain && get(chain + uintptr_t(index) * 8, entry) &&
            entry == expected + 0x30;
    }
    void writer_gate(uintptr_t manager, Snapshot& s) {
        Weak weak{}; uintptr_t wm{}, widgets{}, widget_class{}, material{}; int count{};
        if (!get(base + pinned::widget_manager_weak, weak) || !resolve(weak, wm) || !valid(wm) ||
            !get(wm + 0xa0, widgets) || !get(wm + 0xa8, count) || count < 0 || count > 256 ||
            !class_at(pinned::widget_class, widget_class) || !get(manager + 0x130, material)) return;
        for (int i = 0; i < count; ++i) {
            uintptr_t widget{}; uint8_t kind{}, opening{};
            if (!get(widgets + uintptr_t(i) * 8, widget)) return;
            if (!widget) continue;
            if (!valid(widget) || !get(widget + 0x271, kind)) return;
            if (kind != 8) continue;
            if (!is_a(widget, widget_class) || !get(widget + 0x270, opening)) return;
            s.writer_gate_known = true;
            s.writer_gate = opening != 0 && material && valid(material);
            if (s.writer_gate) { s.writer_widget = widget; s.writer_material = material; }
            return;
        }
        s.writer_gate_known = true;
    }
public:
    Reader(Memory& m, uintptr_t module) : memory(m), base(module) {}
    // Raw UObject validation also used by read-only native scalar adapters.
    bool valid_object(uintptr_t object) { return object && valid(object); }
    Snapshot sample() {
        Snapshot s; Weak w{}; uintptr_t manager{}, klass{};
        if (!base || !get(base + pinned::manager_weak, w) || !resolve(w, manager) || !valid(manager) ||
            !class_at(pinned::manager_class, klass) || !is_a(manager, klass)) return s;
        s.index = w.index; s.serial = w.serial;
        uint8_t state{}, force{};
        if (!get(manager + 0xc8, state)) return s;
        s.state = state;
        if (state > 4) { s.status = 2; return s; }
        if (!get(manager + 0x98, s.reference) || !get(manager + 0x11e, force) ||
            !get(manager + (force ? 0x138 : 0x12c), s.range) ||
            !std::isfinite(s.reference) || s.reference < 0 || !std::isfinite(s.range) || s.range <= 0) {
            if (!still_current(w, manager)) return Snapshot{};
            s.status = 3; return s; // known native state can still silence control cues
        }
        uintptr_t marker{};
        if (get(manager + 0xe0, marker)) {
            if (!marker) s.marker_known = true;
            else {
                uintptr_t marker_class{}, outer{};
                if (class_at(pinned::marker_class, marker_class) && is_a(marker, marker_class) &&
                    get(marker + 0x20, outer) && outer == manager &&
                    get(marker + 0x28, s.marker_time) && std::isfinite(s.marker_time)) {
                    s.marker_known = true; s.marker_present = true;
                }
            }
        }
        writer_gate(manager, s);
        if (!still_current(w, manager)) return Snapshot{};
        s.status = 0;
        return s;
    }
};
} // namespace lisr::rewind
