//
//  KTVHCHTTPConnection.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPConnection.h"
#import "KTVHCHTTPHLSResponse.h"
#import "KTVHCHTTPResponse.h"
#import "KTVHCDataStorage.h"
#import "KTVHCHTTPHeader.h"
#import "KTVHCURLTool.h"
#import "KTVHCLog.h"

@implementation KTVHCHTTPConnection

+ (NSString *)URITokenPing
{
    return @"KTVHTTPCachePing";
}

+ (NSString *)URITokenPlaceHolder
{
    return @"KTVHTTPCachePlaceHolder";
}

+ (NSString *)URITokenLastPathComponent
{
    return @"KTVHTTPCacheLastPathComponent";
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    if (self = [super initWithAsyncSocket:newSocket configuration:aConfig]) {
        KTVHCLogAlloc(self);
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

/*
 Get
 http://qiniuuwmp3.changba.com/941946870.mp4/KTVHTTPCachePlaceHolder/KTVHTTPCacheLastPathComponent.mp4
 
 */
// 在 URL 里面, 除了原始的地址, 还有一些逻辑控制的信息. 
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    KTVHCLogHTTPConnection(@"%p, Receive request\nmethod : %@\npath : %@\nURL : %@", self, method, path, request.url);
    if ([path containsString:[self.class URITokenPing]]) {
        return [[HTTPDataResponse alloc] initWithData:[@"ping" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSMutableArray *components = [path componentsSeparatedByString:@"/"].mutableCopy;
    if (components.count < 3) {
        return [[HTTPErrorResponse alloc] initWithErrorCode:404];
    }
    /*
     <__NSArrayM 0x6000001b0570>(
     ,
     http%3A%2F%2Fqiniuuwmp3%2Echangba%2Ecom%2F941946870%2Emp4,
     KTVHTTPCachePlaceHolder,
     KTVHTTPCacheLastPathComponent.mp4
     )
     */
    NSString *URLString = [[KTVHCURLTool tool] URLDecode:components[1]];
    if (![URLString hasPrefix:@"http"]) {
        return [[HTTPErrorResponse alloc] initWithErrorCode:404];
    }
    
    // URLString 目前, 就是真正的资源地址了.
    NSURL *URL = nil;
    if ([path containsString:[self.class URITokenLastPathComponent]]) {
        URL = [NSURL URLWithString:URLString];
    } else {
        [components removeObjectAtIndex:0];
        [components removeObjectAtIndex:0];
        URLString = URLString.stringByDeletingLastPathComponent;
        if ([path containsString:[self.class URITokenPlaceHolder]]) {
            [components removeObjectAtIndex:0];
        } else {
            URLString = URLString.stringByDeletingLastPathComponent;
        }
        NSString *lastPathComponent = [components componentsJoinedByString:@"/"];
        if ([lastPathComponent hasPrefix:@"http"]) {
            URLString = lastPathComponent;
        } else {
            URLString = [URLString stringByAppendingPathComponent:lastPathComponent];
        }
        URL = [NSURL URLWithString:URLString];
        KTVHCLogHTTPConnection(@"%p, Receive redirect request\nURL : %@", self, URLString);
    }
    KTVHCLogHTTPConnection(@"%p, Accept request\nURL : %@", self, URL);
    /*
     http://qiniuuwmp3.changba.com/941946870.mp4
     
     <CFBasicHash 0x6000018ce380 [0x1bbb34418]>{type = mutable dict, count = 8,
     entries =>
         2 : X-Playback-Session-Id = <CFString 0x6000018fc600 [0x1bbb34418]>{contents = "0BA31534-D4F6-40CC-8E45-B1EB2AFA0134"}
         6 : Range = <CFString 0x600000dfad40 [0x1bbb34418]>{contents = "bytes=0-1"}
         7 : Host = <CFString 0x60000031a880 [0x1bbb34418]>{contents = "localhost:63077"}
         9 : User-Agent = <CFString 0x600002985860 [0x1bbb34418]>{contents = "AppleCoreMedia/1.0.0.20E247 (iPhone; U; CPU OS 16_4 like Mac OS X; en_us)"}
         10 : Accept-Language = <CFString 0x600000df9a80 [0x1bbb34418]>{contents = "en-US,en;q=0.9"}
         11 : Accept-Encoding = identity
         12 : Connection = <CFString 0x600000de48a0 [0x1bbb34418]>{contents = "keep-alive"}
     }
     */
    KTVHCDataRequest *dataRequest = [[KTVHCDataRequest alloc] initWithURL:URL headers:request.allHeaderFields];
    // 如果是 m3u, 则是 HLS 的拆书, 有着特殊的方式.
    if ([URLString containsString:@".m3u"]) {
        return [[KTVHCHTTPHLSResponse alloc] initWithConnection:self dataRequest:dataRequest];
    }
    
    // KTVHCHTTPResponse 应对的, 其实是真正的资源所对应的数据. 
    return [[KTVHCHTTPResponse alloc] initWithConnection:self dataRequest:dataRequest];
}


@end
