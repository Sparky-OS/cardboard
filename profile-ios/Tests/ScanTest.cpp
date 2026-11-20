// SPDX-License-Identifier: GPL-3.0-or-later
#include "ScanPolicy.hpp"
#include <cassert>
#include <iostream>
int main(int argc,char** argv){
    if(argc==2){profile::ScanPolicy scan;auto t=scan.begin();scan.permitted(t,true);scan.scanned(t,argv[1]);assert(scan.phase==profile::Phase::Ready);std::cout<<scan.link<<"\n";return 0;}
    using namespace profile;ScanPolicy s;
    const auto v1=flatheadset::normalizeProfileLink("https://g.co/cardboard");
    assert(flatheadset::viewerBytes(v1)==cardboard::qrcode::getCardboardV1DeviceParams());
    assert(flatheadset::profileFromHandoff(flatheadset::profileHandoff(v1))==v1);
    for(const auto& bad: {"flatheadset://catch?p=AA","flatheadset://viewer?p=AA#x","flatheadset://viewer?p=AA&host=bad","flatheadset://viewer?p=", "flatheadset://viewer?p=../"}){
        bool failed=false;try{flatheadset::profileFromHandoff(bad);}catch(...){failed=true;}assert(failed);
    }
    const std::string qr="https://google.com/cardboard/cfg?p=CgZHb29nbGUSEkNhcmRib2FyZCBJL08gMjAxNR0rGBU9JQHegj0qEAAASEIAAEhCAABIQgAASEJYADUpXA89OggeZnc-Ej6aPlAAYAM";
    const auto transferred=flatheadset::profileFromHandoff(flatheadset::profileHandoff(qr));
    assert(flatheadset::viewerBytes(transferred)==flatheadset::viewerBytes(qr));
    auto a=flatheadset::makeViewer(flatheadset::LensMode::Cardboard,qr,1920,1080,401);
    auto b=flatheadset::makeViewer(flatheadset::LensMode::Cardboard,transferred,1920,1080,401);
    for(int eye=0;eye<2;++eye){assert(a->eyes[eye].indices==b->eyes[eye].indices);for(size_t i=0;i<a->eyes[eye].vertices.size();++i){
        auto x=a->eyes[eye].vertices[i],y=b->eyes[eye].vertices[i];assert(x.x==y.x&&x.y==y.y&&x.u==y.u&&x.v==y.v);
    }}
    auto t=s.begin();assert(!s.permitted(t,false)&&s.phase==Phase::Failed);
    t=s.begin();assert(s.permitted(t,true));assert(s.scanned(t,v1)&&s.phase==Phase::Ready);
    assert(!s.scanned(t,"bad"));s.cancel();assert(s.phase==Phase::Ready);
    t=s.begin();s.cancel();assert(!s.permitted(t,true));assert(!s.scanned(t,v1));
    t=s.begin();s.permitted(t,true);s.scanned(t,"https://goo.gl/Abc");assert(s.phase==Phase::Consent);
    assert(!s.redirect(t,v1));assert(s.resolve(t));assert(!s.redirect(t,v1)&&s.phase==Phase::Ready);
    t=s.begin();s.permitted(t,true);s.scanned(t,"http://goo.gl/Abc");assert(s.remote=="https://goo.gl/Abc");s.resolve(t);
    for(int i=0;i<5;++i){assert(s.redirect(t,"https://goo.gl/Abc"));}assert(!s.redirect(t,"https://goo.gl/Abc")&&s.phase==Phase::Failed);
    for(const auto& bad:{"https://127.0.0.1/x","file:///x","https://goo.gl.evil/a","https://user@goo.gl/a","https://goo.gl:443/a","https://goo.gl/a?x=y","https://g.co/cardboard#bad",""}) {
        t=s.begin();s.permitted(t,true);s.scanned(t,bad);assert(s.phase==Phase::Failed);
    }
    t=s.begin();s.permitted(t,true);s.scanned(t,"https://g.co/x");s.resolve(t);s.fail(t);assert(s.phase==Phase::Failed);
    t=s.begin();s.permitted(t,true);s.scanned(t,"https://g.co/x");s.resolve(t);s.cancel();assert(!s.redirect(t,v1));
    t=s.begin();s.permitted(t,true);s.scanned(t,std::string(24001,'A'));assert(s.phase==Phase::Failed);
    std::cout<<"PASS: permissions, camera result, same v1 bytes, handoff round-trip, malformed links, consent, redirect limit, network failure, cancellation and stale callbacks\n";
}
