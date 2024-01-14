//
//  KTVHCDataDownload.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/12.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDownload.h"
#import "KTVHCData+Internal.h"
#import "KTVHCDataUnitPool.h"
#import "KTVHCDataStorage.h"
#import "KTVHCError.h"
#import "KTVHCLog.h"

#import <UIKit/UIKit.h>

NSString * const KTVHCContentTypeText                   = @"text/";
NSString * const KTVHCContentTypeVideo                  = @"video/";
NSString * const KTVHCContentTypeAudio                  = @"audio/";
NSString * const KTVHCContentTypeAppleHLS1              = @"vnd.apple.mpegURL";
NSString * const KTVHCContentTypeAppleHLS2              = @"application/x-mpegURL";
NSString * const KTVHCContentTypeApplicationMPEG4       = @"application/mp4";
NSString * const KTVHCContentTypeApplicationOctetStream = @"application/octet-stream";
NSString * const KTVHCContentTypeBinaryOctetStream      = @"binary/octet-stream";

@interface KTVHCDownload () <NSURLSessionDataDelegate, NSLocking>

@property (nonatomic, strong) NSLock *coreLock;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, NSError *> *errorDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, KTVHCDataRequest *> *requestDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, id<KTVHCDownloadDelegate>> *delegateDictionary;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation KTVHCDownload

+ (instancetype)download
{
    static KTVHCDownload *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init
{
    if (self = [super init]) {
        KTVHCLogAlloc(self);
        self.timeoutInterval = 30.0f;
        self.coreLock = [[NSLock alloc] init];
        self.backgroundTask = UIBackgroundTaskInvalid;
        self.errorDictionary = [NSMutableDictionary dictionary];
        self.requestDictionary = [NSMutableDictionary dictionary];
        self.delegateDictionary = [NSMutableDictionary dictionary];
        self.sessionDelegateQueue = [[NSOperationQueue alloc] init];
        self.sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.sessionConfiguration.timeoutIntervalForRequest = self.timeoutInterval;
        self.sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                     delegate:self
                                                delegateQueue:self.sessionDelegateQueue];
        self.acceptableContentTypes = @[KTVHCContentTypeText,
                                        KTVHCContentTypeVideo,
                                        KTVHCContentTypeAudio,
                                        KTVHCContentTypeAppleHLS1,
                                        KTVHCContentTypeAppleHLS2,
                                        KTVHCContentTypeApplicationMPEG4,
                                        KTVHCContentTypeApplicationOctetStream,
                                        KTVHCContentTypeBinaryOctetStream];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)availableHeaderKeys
{
    static NSArray<NSString *> *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = @[@"User-Agent",
                @"Connection",
                @"Accept",
                @"Accept-Encoding",
                @"Accept-Language",
                @"Range"];
    });
    return obj;
}

- (NSURLRequest *)requestWithDataRequest:(KTVHCDataRequest *)request
{
    NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:request.URL];
    mRequest.timeoutInterval = self.timeoutInterval;
    mRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [request.headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([self.availableHeaderKeys containsObject:key] ||
            [self.whitelistHeaderKeys containsObject:key]) {
            [mRequest setValue:obj forHTTPHeaderField:key];
        }
    }];
    [self.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [mRequest setValue:obj forHTTPHeaderField:key];
    }];
    return mRequest;;
}

// 真正的对于资源的下载动作, 是在这里.
- (NSURLSessionTask *)downloadWithRequest:(KTVHCDataRequest *)request delegate:(id<KTVHCDownloadDelegate>)delegate
{
    [self lock];
    NSURLRequest *mRequest = [self requestWithDataRequest:request];
    // 使用了 data task, 来做各个请求的实际的请求类.
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mRequest];
    [self.requestDictionary setObject:request forKey:task];
    [self.delegateDictionary setObject:delegate forKey:task];
    task.priority = 1.0;
    // 开启了下载任务之后, 立马就进行了开启.
    [task resume];
    KTVHCLogDownload(@"%p, Add Request\nrequest : %@\nURL : %@\nheaders : %@\nHTTPRequest headers : %@\nCount : %d", self, request, request.URL, request.headers, mRequest.allHTTPHeaderFields, (int)self.delegateDictionary.count);
    [self beginBackgroundTaskAsync];
    [self unlock];
    return task;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self lock];
    KTVHCLogDownload(@"%p, Complete\nError : %@", self, error);
    if ([self.errorDictionary objectForKey:task]) {
        error = [self.errorDictionary objectForKey:task];
    }
    id<KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:task];
    // 下载完成了之后, 通知上层逻辑控件.
    [delegate ktv_download:self didCompleteWithError:error];
    [self.delegateDictionary removeObjectForKey:task];
    [self.requestDictionary removeObjectForKey:task];
    [self.errorDictionary removeObjectForKey:task];
    if (self.delegateDictionary.count <= 0 && self.backgroundTask != UIBackgroundTaskInvalid) {
        [self endBackgroundTaskDelay];
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self lock];
    NSError *error = nil;
    KTVHCDataRequest *dataRequest = nil;
    KTVHCDataResponse *dataResponse = nil;
    NSHTTPURLResponse *HTTPURLResponse = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        HTTPURLResponse = (NSHTTPURLResponse *)response;
        if (HTTPURLResponse.statusCode > 400) {
            error = [KTVHCError errorForResponseUnavailable:task.currentRequest.URL
                                                    request:task.currentRequest
                                                   response:task.response];
        } else {
            // 获取到了正常的 Response, 组织出来业务的 KTVHCDataResponse
            dataRequest = [self.requestDictionary objectForKey:task];
            dataResponse = [[KTVHCDataResponse alloc] initWithURL:dataRequest.URL headers:HTTPURLResponse.allHeaderFields];
        }
    } else {
        error = [KTVHCError errorForResponseUnavailable:task.currentRequest.URL
                                                request:task.currentRequest
                                               response:task.response];
    }
    if (!error) {
        // 这里判断的是, 是否对应的数据类型是非法的.
        BOOL vaild = NO;
        if (dataResponse.contentType.length > 0) {
            for (NSString *obj in self.acceptableContentTypes) {
                if ([[dataResponse.contentType lowercaseString] containsString:[obj lowercaseString]]) {
                    vaild = YES;
                }
            }
            // Disposer 处理者, 清理者.
            if (!vaild && self.unacceptableContentTypeDisposer) {
                vaild = self.unacceptableContentTypeDisposer(dataRequest.URL, dataResponse.contentType);
            }
        }
        if (!vaild) {
            error = [KTVHCError errorForUnsupportContentType:task.currentRequest.URL
                                                     request:task.currentRequest
                                                    response:task.response];
        }
    }
    if (!error) {
        if (dataResponse.contentLength <= 0 ||
            (!KTVHCRangeIsFull(dataRequest.range) &&
             (dataResponse.contentLength != KTVHCRangeGetLength(dataRequest.range)))) {
                error = [KTVHCError errorForResponseUnavailable:task.currentRequest.URL
                                                        request:task.currentRequest
                                                       response:task.response];
            }
    }
    if (!error) {
        long long (^getDeletionLength)(long long) = ^(long long desireLength){
            return desireLength + [KTVHCDataStorage storage].totalCacheLength - [KTVHCDataStorage storage].maxCacheLength;
        };
        long long length = getDeletionLength(dataResponse.contentLength);
        // 这里是需要进行缓存文件的删除工作.
        if (length > 0) {
            [[KTVHCDataUnitPool pool] deleteUnitsWithLength:length];
            // 看来上面的操作, 是真正的删除操作.
            length = getDeletionLength(dataResponse.contentLength);
            if (length > 0) {
                error = [KTVHCError errorForNotEnoughDiskSpace:dataResponse.totalLength
                                                       request:dataResponse.contentLength
                                              totalCacheLength:[KTVHCDataStorage storage].totalCacheLength
                                                maxCacheLength:[KTVHCDataStorage storage].maxCacheLength];
            }
        }
    }
    // 当, 收到 Response 的时候, 会触发业务的一些函数处理.
    // 比如, 类型不匹配, 缓存不够, 当有了这些触发之后, 就取消了后面的流程处理了.
    // 以为在 CompleteWithError 里面, 需要用到这些错误, 所以就提前进行了存储.
    if (error) {
        KTVHCLogDownload(@"%p, Invaild response\nError : %@", self, error);
        [self.errorDictionary setObject:error forKey:task];
        completionHandler(NSURLSessionResponseCancel);
    } else {
        KTVHCLogDownload(@"%p, Receive response\nrequest : %@\nresponse : %@\nHTTPResponse : %@", self, dataRequest, dataResponse, HTTPURLResponse);
        id<KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:task];
        [delegate ktv_download:self didReceiveResponse:dataResponse];
        completionHandler(NSURLSessionResponseAllow);
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    [self lock];
    // 为啥 Log 还需要 lock 一下呢.
    KTVHCLogDownload(@"%p, Perform HTTP redirection\nresponse : %@\nrequest : %@", self, response, request);
    completionHandler(request);
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self lock];
    KTVHCLogDownload(@"%p, Receive data - Begin\nLength : %lld\nURL : %@", self, (long long)data.length, dataTask.originalRequest.URL.absoluteString);
    id<KTVHCDownloadDelegate> delegate = [self.delegateDictionary objectForKey:dataTask];
    [delegate ktv_download:self didReceiveData:data];
    KTVHCLogDownload(@"%p, Receive data - End\nLength : %lld\nURL : %@", self, (long long)data.length, dataTask.originalRequest.URL.absoluteString);
    [self unlock];
}

- (void)lock
{
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

#pragma mark - Background Task

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self beginBackgroundTaskIfNeeded];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self endBackgroundTaskIfNeeded:YES];
}

- (void)beginBackgroundTaskIfNeeded
{
    [self lock];
    // 如果, 当前没有开启后台任务, 又有了后台加载的需求.
    if (self.backgroundTask == UIBackgroundTaskInvalid && self.delegateDictionary.count > 0) {
        __weak typeof(self) weakSelf = self;
        self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf endBackgroundTaskIfNeeded:YES];
        }];
    }
    [self unlock];
}

- (void)endBackgroundTaskIfNeeded:(BOOL)force
{
    [self lock];
    if (force || self.delegateDictionary.count <= 0) {
        if (self.backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
    }
    [self unlock];
}

- (void)beginBackgroundTaskAsync
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            [self beginBackgroundTaskIfNeeded];
        }
    });
}

- (void)endBackgroundTaskDelay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self endBackgroundTaskIfNeeded:NO];
    });
}

@end
