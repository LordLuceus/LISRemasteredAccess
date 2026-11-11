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
        if (name!=lisr::reflection::resolver) { violation=true; throw std::runtime_error("resolver name"); }
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
    const int result=lisr::reflection::read(s,[&](bool,uintptr_t,uintptr_t,uintptr_t){
        ++pushes;
        if (push_mode==1) throw std::runtime_error("pusher before push");
        if (push_mode!=4) s.values.push_back({Value::Userdata,77,{}});
        if (push_mode==2) throw 789;
        if (push_mode==3) { s.values.push_back(Value::num(1)); throw std::runtime_error("two partial pushes"); }
        if (push_mode==5) s.values.push_back(Value::num(2));
    });
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
        if (argc==2 && std::string_view(argv[1])=="--force-failure") check(false,"injected failure");
    } catch (...) { check(false,"uncaught protocol test exception"); }
    std::printf("reflection protocol: %d executed checks, %d failures\n",checks,failures);
    return failures?1:0;
}
