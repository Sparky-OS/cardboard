// SPDX-License-Identifier: GPL-3.0-or-later
// Authored from our call sites. Syntax doubles, not SDK or ABI declarations.
#pragma once
#ifndef FH_OBJC_SYNTAX_ONLY
#error Test doubles cannot enter a product build
#endif
#import <UIKit/UIKit.h>
@interface CALayer : NSObject
@property CGRect frame;
- (void)removeFromSuperlayer;
- (void)insertSublayer:(CALayer*)layer atIndex:(unsigned)index;
@end
@interface UIView (CBLayer)
@property(readonly) CALayer* layer;
@end
@interface UIButton (CBEnabled)
@property BOOL enabled;
@end
@interface NSArray (CBContains)
- (BOOL)containsObject:(id)object;
@end
@interface NSNotification : NSObject
@property(readonly) id object;
@end
constexpr UIInterfaceOrientationMask UIInterfaceOrientationMaskPortrait=2;
constexpr int DISPATCH_QUEUE_SERIAL=0;
dispatch_queue_t dispatch_queue_create(const char*, int);
using AVAuthorizationStatus=NSInteger;
enum { AVAuthorizationStatusNotDetermined,AVAuthorizationStatusAuthorized };
extern NSString *AVMediaTypeVideo,*AVMetadataObjectTypeQRCode,*AVLayerVideoGravityResizeAspectFill;
extern NSString *AVCaptureSessionWasInterruptedNotification,*AVCaptureSessionRuntimeErrorNotification;
@protocol AVCaptureMetadataOutputObjectsDelegate @end
@interface AVCaptureDevice : NSObject
+ (AVAuthorizationStatus)authorizationStatusForMediaType:(NSString*)type;
+ (void)requestAccessForMediaType:(NSString*)type completionHandler:(void (^)(BOOL))handler;
+ (instancetype)defaultDeviceWithMediaType:(NSString*)type;
@end
@interface AVCaptureDeviceInput : NSObject
+ (instancetype)deviceInputWithDevice:(AVCaptureDevice*)device error:(NSError**)error;
@end
@interface AVCaptureOutput : NSObject @end
@interface AVCaptureConnection : NSObject @end
@interface AVCaptureMetadataOutput : AVCaptureOutput
@property(readonly) NSArray* availableMetadataObjectTypes;
@property(copy) NSArray* metadataObjectTypes;
- (void)setMetadataObjectsDelegate:(id<AVCaptureMetadataOutputObjectsDelegate>)delegate queue:(dispatch_queue_t)queue;
@end
@interface AVCaptureSession : NSObject
- (BOOL)canAddInput:(AVCaptureDeviceInput*)input;
- (BOOL)canAddOutput:(AVCaptureOutput*)output;
- (void)addInput:(AVCaptureDeviceInput*)input;
- (void)addOutput:(AVCaptureOutput*)output;
- (void)startRunning;
- (void)stopRunning;
@end
@interface AVCaptureVideoPreviewLayer : CALayer
+ (instancetype)layerWithSession:(AVCaptureSession*)session;
@property(copy) NSString* videoGravity;
@end
@interface AVMetadataObject : NSObject
@property(readonly) NSString* type;
@end
@interface AVMetadataMachineReadableCodeObject : AVMetadataObject
@property(readonly) NSString* stringValue;
@end
@interface NSURL (CBURL)
+ (instancetype)URLWithString:(NSString*)string;
@end
@interface NSURLRequest : NSObject
@property(readonly) NSURL* URL;
@end
@interface NSMutableURLRequest : NSURLRequest
+ (instancetype)requestWithURL:(NSURL*)url;
@property(copy) NSString* HTTPMethod;
@end
@interface NSURLResponse : NSObject @end
@interface NSHTTPURLResponse : NSURLResponse @end
@interface NSURLSessionTask : NSObject
- (void)resume;
@end
@interface NSURLSessionDataTask : NSURLSessionTask @end
@interface NSOperationQueue : NSObject
@property(class,readonly) NSOperationQueue* mainQueue;
@end
@interface NSURLSessionConfiguration : NSObject
@property(class,readonly) NSURLSessionConfiguration* ephemeralSessionConfiguration;
@property double timeoutIntervalForRequest;
@property double timeoutIntervalForResource;
@property(strong) id HTTPCookieStorage;
@property(strong) id URLCache;
@end
using NSURLSessionResponseDisposition=NSInteger;
constexpr NSURLSessionResponseDisposition NSURLSessionResponseCancel=0;
@protocol NSURLSessionDataDelegate @end
@interface NSURLSession : NSObject
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration*)config delegate:(id)delegate delegateQueue:(NSOperationQueue*)queue;
- (NSURLSessionDataTask*)dataTaskWithRequest:(NSURLRequest*)request;
- (void)invalidateAndCancel;
- (void)finishTasksAndInvalidate;
@end
@interface UIApplication (CBOpen)
- (void)openURL:(NSURL*)url options:(NSDictionary*)options completionHandler:(void (^)(BOOL))completion;
@end
