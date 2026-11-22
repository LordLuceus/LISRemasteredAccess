#include "reflection_protocol.h"
#include <cstdio>
#include <memory>
#include <vector>
#include <functional>
#include <string_view>
using namespace std::string_view_literals;
namespace {
int checks=0, failures=0;
void check(bool ok, const char* label) {
    ++checks; if (!ok) { ++failures; std::fprintf(stderr,"FAIL: %s\n",label); }
}
struct Value {
    enum Type { Userdata, String, Integer, Function, Nil } type;
    int64_t number=0;
    std::shared_ptr<std::string> text;
    static Value str(std::string s) { return {String,0,std::make_shared<std::string>(std::move(s))}; }
    static Value num(int64_t n) { return {Integer,n,{}}; }
};
struct Stack {
    std::vector<Value> values{{Value::Userdata,42,{}},Value::str("DialogButtons_Array")};
    std::vector<Value> results{Value::num(65536),Value::num(131072),Value::num(48),Value::num(1)};
    std::vector<int64_t> integers;
    int duplicates=0, calls=0, discarded=0;
    bool violation=false, prepare_throw=false, resolver_throw=false, getter_throw=false;
    bool rewind_view=false, padlock=false;
    int index(int i) const {
        const int n=int(values.size()); const int x=i<0?n+i:i-1;
        if (x<0 || x>=n) throw std::runtime_error("fake stack index");
        return x;
    }
    int get_stack_size() const { return int(values.size()); }
    bool is_userdata(int i) const { return values.at(index(i)).type==Value::Userdata; }
    bool is_string(int i) const { return values.at(index(i)).type==Value::String; }
    bool is_integer(int i) const { return values.at(index(i)).type==Value::Integer; }
    void insert_value(int from,int to) {
        Value copy=values.at(index(from));
        if (to<1 || to>int(values.size())+1) throw std::runtime_error("insert position");
        values.insert(values.begin()+to-1,copy); ++duplicates;
    }
    void discard_value(int i) { values.erase(values.begin()+index(i)); ++discarded; }
    std::string_view get_string(int i) {
        auto& v=values.at(index(i)); if (v.type!=Value::String) throw std::runtime_error("string type");
        // Duplicates share the same string; the original argument roots its storage.
        std::string_view s=*v.text; values.erase(values.begin()+index(i)); return s;
    }
    int64_t get_integer(int i) {
        auto v=values.at(index(i)); if (v.type!=Value::Integer) throw std::runtime_error("integer type");
        values.erase(values.begin()+index(i)); integers.push_back(v.number);
        if (getter_throw && integers.size()==2) throw 123;
        return v.number;
    }
    void prepare_function_call(std::string_view name) {
        if (name!=(padlock ? lisr::reflection::padlock_resolver : rewind_view ? lisr::reflection::rewind_resolver : lisr::reflection::resolver)) { violation=true; throw std::runtime_error("resolver name"); }
        values.push_back({Value::Function,0,{}});
        if (prepare_throw) throw std::runtime_error("prepare after push");
    }
    void call_function(int nargs,int nresults) {
        ++calls;
        if (nargs!=2 || nresults!=4 || values.size()!=5 || values[2].type!=Value::Function ||
            values[3].type!=Value::Userdata || values[3].number!=42 || values[4].type!=Value::String ||
            values[4].text!=values[1].text || values[0].number!=42) {
            violation=true; throw std::runtime_error("argument order/original preservation");
        }
        values.resize(2);
        if (resolver_throw) { values.push_back(Value::num(99)); throw 456; }
        values.insert(values.end(),results.begin(),results.end());
    }
    void set_nil() { values.push_back({Value::Nil,0,{}}); }
    void set_string(std::string_view s) { values.push_back(Value::str(std::string(s))); }
};
void rejected(Stack s, const char* label, int push_mode=0, bool expected_push=false) {
    const auto original=s.values; int pushes=0;
    auto push=[&](int,uintptr_t,uintptr_t,uintptr_t){
        ++pushes;
        if (push_mode==1) throw std::runtime_error("pusher before push");
        if (push_mode!=4) s.values.push_back({Value::Userdata,77,{}});
        if (push_mode==2) throw 789;
        if (push_mode==3) { s.values.push_back(Value::num(1)); throw std::runtime_error("two partial pushes"); }
        if (push_mode==5) s.values.push_back(Value::num(2));
    };
    const int result=s.padlock ? lisr::reflection::read_padlock(s,push) : lisr::reflection::read(s,push);
    check(result==2,label);
    check(s.values.size()==original.size()+2,"failure stack shape");
    bool preserved=s.values.size()>=original.size();
    for (size_t i=0; preserved && i<original.size(); ++i)
        preserved=s.values[i].type==original[i].type && s.values[i].number==original[i].number && s.values[i].text==original[i].text;
    check(preserved,"original arguments preserved on rejection");
    check(s.values[s.values.size()-2].type==Value::Nil && s.values.back().type==Value::String,"nil/error results");
    check(pushes==(expected_push?1:0),"no pusher on invalid input/resolution");
    check(!s.violation,"resolver argument layout on rejection");
}
}
int main(int argc,char** argv) {
    try {
        for (bool array : {true,false}) {
            Stack s;
            if (!array) { s.values[1]=Value::str("DialogText");s.results[3]=Value::num(2); }
            const auto original=s.values; int pushes=0;
            const int r=lisr::reflection::read(s,[&](bool a,uintptr_t owner,uintptr_t property,uintptr_t offset){
                ++pushes; check(a==array,"typed pusher choice");
                check(owner==65536 && property==131072 && offset==48,"destructive getter result order");
                check(s.values.size()==2 && s.values[1].text==original[1].text,"pusher sees original arguments only");
                s.values.push_back({Value::Userdata,77,{}});
            });
            check(r==1 && pushes==1 && s.values.size()==3,"successful result shape");
            check(s.duplicates==3 && s.calls==1,"three duplicates, one resolver call");
            check(!s.violation && s.values[0].number==42 && s.values[1].text==original[1].text,"success preserves originals");
            check(s.integers==std::vector<int64_t>{array?1:2,48,131072,65536},"LIFO destructive integer getters");
        }
        {Stack s;s.values.clear();rejected(s,"zero arguments");}
        {Stack s;s.values.pop_back();rejected(s,"one argument");}
        {Stack s;s.values.push_back(Value::num(1));rejected(s,"extra argument");}
        {Stack s;s.values[0]=Value::num(123);rejected(s,"numeric owner forbidden");}
        {Stack s;s.values[1]=Value::num(123);rejected(s,"numeric property forbidden");}
        {Stack s;s.values[1]=Value::str("OtherProperty");rejected(s,"whitelist");}
        {Stack s;s.values[1]=Value::str("Overlay_Rewind");rejected(s,"dialogue export does not acquire rewind fields");}
        for (auto name : {"RewindBarMaterialInstance","Overlay_Rewind","CanvasPanel_Rewind","Button_RewindIndicator","Image_RewindButtonIndicator"}) {
            Stack s; s.rewind_view=true;s.values[1]=Value::str(name);s.results[3]=Value::num(2);
            int pushes=0;
            int r=lisr::reflection::read(s,[&](bool array,uintptr_t owner,uintptr_t property,uintptr_t offset){
                check(!array && owner==65536 && property==131072 && offset==48,"rewind typed fresh object pusher");
                ++pushes;s.values.push_back({Value::Userdata,77,{}});
            },true);
            check(r==1 && pushes==1 && !s.violation,"separate rewind resolver and whitelist");
        }
        {Stack s;s.rewind_view=true;int pushes=0;auto r=lisr::reflection::read(s,[&](bool,uintptr_t,uintptr_t,uintptr_t){++pushes;},true);
            check(r==2 && !pushes && !s.calls,"rewind export cannot acquire dialogue arrays");}
        {Stack s;s.prepare_throw=true;rejected(s,"prepare partial push");}
        {Stack s;s.resolver_throw=true;rejected(s,"resolver partial push/nonstandard exception");}
        {Stack s;s.getter_throw=true;rejected(s,"getter throws after destructive read");}
        {Stack s;s.results.pop_back();rejected(s,"short result shape");}
        {Stack s;s.results.push_back(Value::num(1));rejected(s,"long result shape");}
        for (int i=0;i<4;++i) {Stack s;s.results[i]=Value::str("not integer");rejected(s,"result type rejection");}
        for (auto [i,value] : std::vector<std::pair<int,int64_t>>{{0,0},{0,-1},{1,0},{1,-1},{2,-1},{2,int64_t(INT32_MAX)+1},{3,0},{3,2}}) {
            Stack s;s.results[i]=Value::num(value);rejected(s,"provenance rejection");
        }
        for (int mode=1;mode<=5;++mode) rejected(Stack{},"pusher failure/shape cleanup",mode,true);
        // Every padlock kind exercises success and the complete rejection/cleanup
        // matrix, including a descriptor changing on the very next live call.
        int kind=0;
        for (auto name : {"DigitWidgets_Array","TextBlock_Digit","Digit"}) {
            ++kind;
            Stack base; base.padlock=true; base.values[1]=Value::str(name);base.results[3]=Value::num(kind);
            for (int64_t descriptor : {131072,196608}) {
                Stack s=base;s.results[1]=Value::num(descriptor);int pushes=0;
                auto r=lisr::reflection::read_padlock(s,[&](int actual,uintptr_t owner,uintptr_t property,uintptr_t offset){
                    ++pushes;
                    check(actual==kind && owner==65536 && property==static_cast<uintptr_t>(descriptor) && offset==48,"padlock current descriptor and typed dispatch");
                    check(s.values.size()==2,"padlock pusher sees original arguments only");
                    if (actual==3) s.values.push_back(Value::num(-7));
                    else s.values.push_back({Value::Userdata,77,{}});
                });
                check(r==1 && pushes==1 && s.values.size()==3 && !s.violation,"padlock success shape");
                check(s.values.back().type==(kind==3?Value::Integer:Value::Userdata),"padlock scalar versus wrapper result");
                if (kind==3) check(s.values.back().number==-7,"signed scalar result");
                check(s.duplicates==3 && s.calls==1,"padlock fresh resolver call");
                check(s.integers==std::vector<int64_t>{kind,48,descriptor,65536},"padlock resolver result order");
            }
            {auto s=base;s.values.clear();rejected(s,"padlock zero arguments");}
            {auto s=base;s.values.pop_back();rejected(s,"padlock short arguments");}
            {auto s=base;s.values.push_back(Value::num(1));rejected(s,"padlock extra arguments");}
            for (int i=0;i<2;++i) {auto s=base;s.values[i]=Value::num(1);rejected(s,"padlock argument types");}
            {auto s=base;s.prepare_throw=true;rejected(s,"padlock missing resolver/prepare cleanup");}
            {auto s=base;s.resolver_throw=true;rejected(s,"padlock resolver error cleanup");}
            {auto s=base;s.getter_throw=true;rejected(s,"padlock destructive getter error cleanup");}
            {auto s=base;s.results.pop_back();rejected(s,"padlock short results");}
            {auto s=base;s.results.push_back(Value::num(1));rejected(s,"padlock extra results");}
            for (int i=0;i<4;++i) {auto s=base;s.results[i]=Value::str("bad");rejected(s,"padlock malformed result");}
            for (auto [i,value] : std::vector<std::pair<int,int64_t>>{{0,0},{0,-1},{1,0},{1,-1},{2,0},{2,-1},{2,int64_t(INT32_MAX)+1},{2,INT64_MAX}}) {
                auto s=base;s.results[i]=Value::num(value);rejected(s,"padlock invalid address/zero or overflowing offset");
            }
            for (int wrong : {0,1,2,3,4}) if (wrong!=kind) {
                auto s=base;s.results[3]=Value::num(wrong);rejected(s,"padlock wrong kind");
            }
            for (int mode=1;mode<=5;++mode) rejected(base,"padlock partial pusher/shape cleanup",mode,true);
            for (auto forbidden : {"DialogButtons_Array","DialogText","RewindBarMaterialInstance","Overlay_Rewind","CanvasPanel_Rewind","Button_RewindIndicator","Image_RewindButtonIndicator","OtherProperty"}) {
                auto s=base;s.values[1]=Value::str(forbidden);rejected(s,"padlock cross-allowlist rejection");
            }
            {Stack s;s.values[1]=Value::str(name);rejected(s,"dialogue rejects padlock fields");}
            {Stack s;s.rewind_view=true;s.values[1]=Value::str(name);int pushes=0;
                auto r=lisr::reflection::read(s,[&](bool,uintptr_t,uintptr_t,uintptr_t){++pushes;},true);
                check(r==2 && !pushes && !s.calls,"rewind rejects padlock fields");}
        }
        if (argc==2 && std::string_view(argv[1])=="--force-failure") check(false,"injected failure");
    } catch (...) { check(false,"uncaught protocol test exception"); }
    std::printf("reflection protocol: %d executed checks, %d failures\n",checks,failures);
    return failures?1:0;
}
