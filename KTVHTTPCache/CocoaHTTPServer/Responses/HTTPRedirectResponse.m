#import "HTTPRedirectResponse.h"
#import "HTTPLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_OFF; // | HTTP_LOG_FLAG_TRACE;

// 应该重写的, 应该是 HttpConnection 这个类.
// 通过这个类, 根据 Request 的信息, 来返回不同的 Resposne 对象.
// 真正的发送的, 其实是这个 Resposne 对象里面的内容.
@implementation HTTPRedirectResponse

- (id)initWithPath:(NSString *)path
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		
		redirectPath = [path copy];
	}
	return self;
}

// 没有 body 的数据
- (UInt64)contentLength
{
	return 0;
}

// 没有 body 的数据.
- (UInt64)offset
{
	return 0;
}

- (void)setOffset:(UInt64)offset
{
	// Nothing to do
}

// 没有 body 的数据.
- (NSData *)readDataOfLength:(NSUInteger)length
{
	HTTPLogTrace();
	
	return nil;
}

- (BOOL)isDone
{
	return YES;
}

// 只会在 httpRespHeader 里面, 添加一个 location, 用来做重定向数据的标识. 
- (NSDictionary *)httpHeaders
{
	HTTPLogTrace();
	
	return [NSDictionary dictionaryWithObject:redirectPath forKey:@"Location"];
}

- (NSInteger)status
{
	HTTPLogTrace();
	
	return 302;
}

- (void)dealloc
{
	HTTPLogTrace();
	
}

@end
