// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "ProfileLink.hpp"
#include <cstdint>
namespace profile {
enum class Phase { Idle, Permission, Scanning, Consent, Resolving, Ready, Failed };
inline std::string shortLink(std::string url) {
    if(url.rfind("http://",0)==0)url.replace(0,7,"https://");
    if(url.rfind("https://",0)!=0)url="https://"+url;
    size_t path=0;
    for(const char* prefix:{"https://goo.gl/","https://g.co/"})if(url.rfind(prefix,0)==0)path=std::string(prefix).size();
    if(!path || url.size()==path || url.size()>256)return {};
    for(size_t i=path;i<url.size();++i){char c=url[i];if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='/'||c=='_'||c=='-'))return {};}
    return url;
}
struct ScanPolicy {
    Phase phase=Phase::Idle;
    uint64_t generation=0;
    unsigned redirects=0;
    std::string link, remote;
    uint64_t begin(){++generation;phase=Phase::Permission;link.clear();remote.clear();redirects=0;return generation;}
    bool current(uint64_t token) const {return generation==token;}
    bool permitted(uint64_t token,bool yes){if(!current(token)||phase!=Phase::Permission)return false;phase=yes?Phase::Scanning:Phase::Failed;return yes;}
    bool scanned(uint64_t token,const std::string& value){
        if(!current(token)||phase!=Phase::Scanning)return false;
        try{link=flatheadset::normalizeProfileLink(value);phase=Phase::Ready;}
        catch(...){remote=shortLink(value);phase=remote.empty()?Phase::Failed:Phase::Consent;}
        return true;
    }
    bool resolve(uint64_t token){if(!current(token)||phase!=Phase::Consent)return false;phase=Phase::Resolving;return true;}
    // Called for each redirect before allowing the next request. Full profile URLs are parsed locally.
    bool redirect(uint64_t token,const std::string& value){
        if(!current(token)||phase!=Phase::Resolving)return false;
        try{link=flatheadset::normalizeProfileLink(value);phase=Phase::Ready;return false;}
        catch(...){remote=shortLink(value);if(remote.empty()||++redirects>5){phase=Phase::Failed;return false;}return true;}
    }
    void fail(uint64_t token){if(current(token)&&phase!=Phase::Ready)phase=Phase::Failed;}
    void cancel(){++generation;if(phase!=Phase::Ready)phase=Phase::Idle;remote.clear();}
};
}
