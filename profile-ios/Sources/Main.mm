/*
 * Copyright 2019 Google LLC
 * Camera/metadata path adapted from sdk/qrcode/ios/qr_scan_view_controller.mm
 * at 8bd424da7f1e399255a1b6e7c02be8e281ecc974 (Apache-2.0).
 * This application and its shared profile validation are GPL-3.0-or-later.
 */
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#include "ScanPolicy.hpp"

@interface CBProfileController : UIViewController <AVCaptureMetadataOutputObjectsDelegate, NSURLSessionDataDelegate> {
    profile::ScanPolicy _policy;
    AVCaptureSession *_capture;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_preview;
    dispatch_queue_t _cameraQueue;
    NSURLSession *_resolver;
    uint64_t _resolveToken;
    UILabel *_status;
    UIButton *_scan;
    UIButton *_use;
    UIButton *_resolve;
    UIButton *_cancel;
    BOOL _visible;
}
@end
@implementation CBProfileController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.blackColor;
    _cameraQueue=dispatch_queue_create("org.sparkyos.cardboard.camera",DISPATCH_QUEUE_SERIAL);
    _status=[UILabel new];_status.numberOfLines=0;_status.textColor=UIColor.whiteColor;_status.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:_status];
    _scan=[self button:@"scan" action:@selector(scan)];
    _use=[self button:@"use" action:@selector(use)];
    _resolve=[self button:@"resolve" action:@selector(resolve)];
    _cancel=[self button:@"cancel" action:@selector(cancel)];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:) name:AVCaptureSessionWasInterruptedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
    [self update:@"intro"];
}
- (UIButton*)button:(NSString*)key action:(SEL)action {
    UIButton* b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:NSLocalizedString(key,nil) forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];return b;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const CGRect bounds=self.view.bounds;
    const CGFloat w=bounds.size.width,h=bounds.size.height;
    _status.frame=CGRectMake(16,32,w-32,110);
    _preview.frame=CGRectMake(16,150,w-32,MAX(40,h-380));
    _scan.frame=CGRectMake(16,h-220,w-32,44);
    _resolve.frame=CGRectMake(16,h-170,w-32,44);
    _use.frame=CGRectMake(16,h-120,w-32,44);
    _cancel.frame=CGRectMake(16,h-70,w-32,44);
}
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];_visible=YES;}
- (void)viewWillDisappear:(BOOL)animated {[super viewWillDisappear:animated];_visible=NO;[self background];}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UIInterfaceOrientationMaskPortrait;}
- (void)update:(NSString*)key {
    _status.text=NSLocalizedString(key,nil);
    _use.enabled=_policy.phase==profile::Phase::Ready;
    _resolve.hidden=_policy.phase!=profile::Phase::Consent;
    _scan.enabled=_policy.phase!=profile::Phase::Permission && _policy.phase!=profile::Phase::Resolving;
}
- (void)stopCamera {
    AVCaptureSession* capture=_capture;_capture=nil;_output=nil;
    [_preview removeFromSuperlayer];_preview=nil;
    if(capture)dispatch_async(_cameraQueue, ^{[capture stopRunning];});
}
- (void)cancel {
    _policy.cancel();[_resolver invalidateAndCancel];_resolver=nil;[self stopCamera];
    [self update:_policy.phase==profile::Phase::Ready?@"ready":@"intro"];
}
- (void)background {[self cancel];}
- (void)interrupted:(NSNotification*)notification {
    id capture=notification.object;
    // Notifications may arrive on the capture worker. UI and policy always stay on main.
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self->_capture && self->_capture==capture){self->_policy.cancel();[self stopCamera];[self update:@"camera_failed"];}
    });
}
- (void)scan {
    [self cancel];const auto token=_policy.begin();[self update:@"permission_wait"];
    const AVAuthorizationStatus status=[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(status==AVAuthorizationStatusNotDetermined){
        __weak CBProfileController* weakSelf=self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL allowed){
            dispatch_async(dispatch_get_main_queue(), ^{[weakSelf permission:allowed token:token];});
        }];
    }else [self permission:status==AVAuthorizationStatusAuthorized token:token];
}
- (void)permission:(BOOL)allowed token:(uint64_t)token {
    if(!_visible || !_policy.current(token))return;
    if(!_policy.permitted(token,allowed)){[self update:@"permission_denied"];return;}
    AVCaptureDevice* camera=[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError* error=nil;
    AVCaptureDeviceInput* input=camera?[AVCaptureDeviceInput deviceInputWithDevice:camera error:&error]:nil;
    AVCaptureSession* capture=[AVCaptureSession new];
    AVCaptureMetadataOutput* output=[AVCaptureMetadataOutput new];
    if(!input || ![capture canAddInput:input]){_policy.fail(token);[self update:@"camera_failed"];return;}
    [capture addInput:input];
    if(![capture canAddOutput:output]){_policy.fail(token);[self update:@"camera_failed"];return;}
    [capture addOutput:output];
    if(![output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]){_policy.fail(token);[self update:@"camera_failed"];return;}
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode];
    _capture=capture;_output=output;
    _preview=[AVCaptureVideoPreviewLayer layerWithSession:capture];
    _preview.videoGravity=AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:_preview atIndex:0];
    [self.view setNeedsLayout];[self update:@"aim"];
    // A serial worker orders every stop before the next start and never blocks UIKit.
    dispatch_async(_cameraQueue, ^{[capture startRunning];});
}
- (void)captureOutput:(AVCaptureOutput*)output didOutputMetadataObjects:(NSArray*)objects fromConnection:(AVCaptureConnection*)connection {
    if(!_capture || output!=_output || _policy.phase!=profile::Phase::Scanning)return;
    for(AVMetadataObject* object in objects){
        if(![object isKindOfClass:AVMetadataMachineReadableCodeObject.class] || ![object.type isEqualToString:AVMetadataObjectTypeQRCode])continue;
        NSString* text=((AVMetadataMachineReadableCodeObject*)object).stringValue;
        _policy.scanned(_policy.generation,text.UTF8String ?: "");[self stopCamera];
        [self update:_policy.phase==profile::Phase::Ready?@"ready":_policy.phase==profile::Phase::Consent?@"network_note":@"invalid"];
        break;
    }
}
- (void)resolve {
    if(!_policy.resolve(_policy.generation))return;
    _resolveToken=_policy.generation;
    NSURLSessionConfiguration* config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest=10;config.timeoutIntervalForResource=15;
    config.HTTPCookieStorage=nil;config.URLCache=nil;
    _resolver=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    NSMutableURLRequest* request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:_policy.remote.c_str()]]];
    request.HTTPMethod=@"HEAD";
    [self update:@"resolving"];[[_resolver dataTaskWithRequest:request] resume];
}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void (^)(NSURLRequest*))completion {
    if(session!=_resolver || !_policy.current(_resolveToken)){completion(nil);return;}
    const bool follow=_policy.redirect(_resolveToken,request.URL.absoluteString.UTF8String ?: "");
    if(follow){
        NSMutableURLRequest* next=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:_policy.remote.c_str()]]];
        next.HTTPMethod=@"HEAD";completion(next);
    }else{
        completion(nil);[session invalidateAndCancel];_resolver=nil;
        [self update:_policy.phase==profile::Phase::Ready?@"ready":@"resolve_failed"];
    }
}
- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)task didReceiveResponse:(NSURLResponse*)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    // Only redirects ending at a locally parsed profile are useful. Never download a page/body.
    completion(NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)error {
    if(session!=_resolver)return;
    _policy.fail(_resolveToken);[session finishTasksAndInvalidate];_resolver=nil;
    [self update:@"resolve_failed"];
}
- (void)use {
    if(_policy.phase!=profile::Phase::Ready)return;
    const auto handoff=flatheadset::profileHandoff(_policy.link);
    NSURL* url=[NSURL URLWithString:[NSString stringWithUTF8String:handoff.c_str()]];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL opened){
        if(!opened)dispatch_async(dispatch_get_main_queue(), ^{[self update:@"receiver_missing"];});
    }];
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_resolver invalidateAndCancel];
    AVCaptureSession* capture=_capture;
    if(capture)dispatch_async(_cameraQueue, ^{[capture stopRunning];});
}
@end
@interface CBAppDelegate : UIResponder <UIApplicationDelegate>
@property(strong,nonatomic) UIWindow* window;
@end
@implementation CBAppDelegate
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[CBProfileController new];[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char** argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(CBAppDelegate.class));}}
