//
//  KTVHCDataRequest.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KTVHTTPCache/KTVHCRange.h>

/*
 第一次的请求.
 
 (lldb) po self.request.URL
 http://qiniuuwmp3.changba.com/941946870.mp4

 (lldb) po self.request.headers
 {
     "Accept-Encoding" = identity;
     "Accept-Language" = "en-US,en;q=0.9";
     Connection = "keep-alive";
     Host = "localhost:55472";
     Range = "bytes=0-1";
     "User-Agent" = "AppleCoreMedia/1.0.0.20E247 (iPhone; U; CPU OS 16_4 like Mac OS X; en_us)";
     "X-Playback-Session-Id" = "5315D6A0-BD76-40EF-AA6E-44302493C463";
 }

 (lldb) po self.request.range.start
 0

 (lldb) po self.request.range.end
 1
 */

@interface KTVHCDataRequest : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy, readonly) NSURL *URL;
@property (nonatomic, copy, readonly) NSDictionary *headers;
@property (nonatomic, readonly) KTVHCRange range;

@end
