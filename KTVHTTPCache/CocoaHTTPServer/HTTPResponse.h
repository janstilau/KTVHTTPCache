#import <Foundation/Foundation.h>


@protocol HTTPResponse

/**
 * Returns the length of the data in bytes.
 * If you don't know the length in advance, implement the isChunked method and have it return YES.
**/
- (UInt64)contentLength;

/**
 * The HTTP server supports range requests in order to allow things like
 * file download resumption and optimized streaming on mobile devices.
**/
- (UInt64)offset;
- (void)setOffset:(UInt64)offset;

/**
 * Returns the data for the response.
 * You do not have to return data of the exact length that is given.
 * You may optionally return data of a lesser length.
 * However, you must never return data of a greater length than requested.
 * Doing so could disrupt proper support for range requests.
 * 
 * To support asynchronous responses, read the discussion at the bottom of this header.
**/
- (NSData *)readDataOfLength:(NSUInteger)length;

/**
 * Should only return YES after the HTTPConnection has read all available data.
 * That is, all data for the response has been returned to the HTTPConnection via the readDataOfLength method.
**/
- (BOOL)isDone;

@optional

/**
 * If you need time to calculate any part of the HTTP response headers (status code or header fields),
 * this method allows you to delay sending the headers so that you may asynchronously execute the calculations.
 * Simply implement this method and return YES until you have everything you need concerning the headers.
 * 
 * This method ties into the asynchronous response architecture of the HTTPConnection.
 * You should read the full discussion at the bottom of this header.
 * 
 * If you return YES from this method,
 * the HTTPConnection will wait for you to invoke the responseHasAvailableData method.
 * After you do, the HTTPConnection will again invoke this method to see if the response is ready to send the headers.
 * 
 * You should only delay sending the headers until you have everything you need concerning just the headers.
 * Asynchronously generating the body of the response is not an excuse to delay sending the headers.
 * Instead you should tie into the asynchronous response architecture, and use techniques such as the isChunked method.
 * 
 * Important: You should read the discussion at the bottom of this header.
**/
- (BOOL)delayResponseHeaders;

/**
 * Status code for response.
 * Allows for responses such as redirect (301), etc.
**/
- (NSInteger)status;

/**
 * If you want to add any extra HTTP headers to the response,
 * simply return them in a dictionary in this method.
**/
- (NSDictionary *)httpHeaders;

/**
 * If you don't know the content-length in advance,
 * implement this method in your custom response class and return YES.
 * 
 * Important: You should read the discussion at the bottom of this header.
**/
- (BOOL)isChunked;

/**
 * This method is called from the HTTPConnection class when the connection is closed,
 * or when the connection is finished with the response.
 * If your response is asynchronous, you should implement this method so you know not to
 * invoke any methods on the HTTPConnection after this method is called (as the connection may be deallocated).
**/
- (void)connectionDidClose;

@end


/**
 * Important notice to those implementing custom asynchronous and/or chunked responses:
 * 
 * HTTPConnection supports asynchronous responses.  All you have to do in your custom response class is
 * asynchronously generate the response, and invoke HTTPConnection's responseHasAvailableData method.
 * You don't have to wait until you have all of the response ready to invoke this method.  For example, if you
 * generate the response in incremental chunks, you could call responseHasAvailableData after generating
 * each chunk.  Please see the HTTPAsyncFileResponse class for an example of how to do this.
 * 
 * The normal flow of events for an HTTPConnection while responding to a request is like this:
 *  - Send http resopnse headers
 *  - Get data from response via readDataOfLength method.
 *  - Add data to asyncSocket's write queue.
 *  - Wait for asyncSocket to notify it that the data has been sent.
 *  - Get more data from response via readDataOfLength method.
 *  - ... continue this cycle until the entire response has been sent.
 * 
 * With an asynchronous response, the flow is a little different.
 * 
 * First the HTTPResponse is given the opportunity to postpone sending the HTTP response headers.
 * This allows the response to asynchronously execute any code needed to calculate a part of the header.
 * An example might be the response needs to generate some custom header fields,
 * or perhaps the response needs to look for a resource on network-attached storage.
 * Since the network-attached storage may be slow, the response doesn't know whether to send a 200 or 404 yet.
 * In situations such as this, the HTTPResponse simply implements the delayResponseHeaders method and returns YES.
 * After returning YES from this method, the HTTPConnection will wait until the response invokes its
 * responseHasAvailableData method. After this occurs, the HTTPConnection will again query the delayResponseHeaders
 * method to see if the response is ready to send the headers.
 * This cycle will continue until the delayResponseHeaders method returns NO.
 * 
 * You should only delay sending the response headers until you have everything you need concerning just the headers.
 * Asynchronously generating the body of the response is not an excuse to delay sending the headers.
 * 
 * After the response headers have been sent, the HTTPConnection calls your readDataOfLength method.
 * You may or may not have any available data at this point. If you don't, then simply return nil.
 * You should later invoke HTTPConnection's responseHasAvailableData when you have data to send.
 * 
 * You don't have to keep track of when you return nil in the readDataOfLength method, or how many times you've invoked
 * responseHasAvailableData. Just simply call responseHasAvailableData whenever you've generated new data, and
 * return nil in your readDataOfLength whenever you don't have any available data in the requested range.
 * HTTPConnection will automatically detect when it should be requesting new data and will act appropriately.
 * 
 * It's important that you also keep in mind that the HTTP server supports range requests.
 * The setOffset method is mandatory, and should not be ignored.
 * Make sure you take into account the offset within the readDataOfLength method.
 * You should also be aware that the HTTPConnection automatically sorts any range requests.
 * So if your setOffset method is called with a value of 100, then you can safely release bytes 0-99.
 * 
 * HTTPConnection can also help you keep your memory footprint small.
 * Imagine you're dynamically generating a 10 MB response.  You probably don't want to load all this data into
 * RAM, and sit around waiting for HTTPConnection to slowly send it out over the network.  All you need to do
 * is pay attention to when HTTPConnection requests more data via readDataOfLength.  This is because HTTPConnection
 * will never allow asyncSocket's write queue to get much bigger than READ_CHUNKSIZE bytes.  You should
 * consider how you might be able to take advantage of this fact to generate your asynchronous response on demand,
 * while at the same time keeping your memory footprint small, and your application lightning fast.
 * 
 * If you don't know the content-length in advanced, you should also implement the isChunked method.
 * This means the response will not include a Content-Length header, and will instead use "Transfer-Encoding: chunked".
 * There's a good chance that if your response is asynchronous and dynamic, it's also chunked.
 * If your response is chunked, you don't need to worry about range requests.
**/

/*
 对于实现自定义异步和/或分块响应的人，有重要提示：
 HTTPConnection支持异步响应。在自定义响应类中，您只需异步生成响应，并调用HTTPConnection的responseHasAvailableData方法。
 
 您无需等到所有响应准备就绪后再调用此方法。例如，如果您以增量块生成响应，则可以在生成每个块后调用responseHasAvailableData。
 请参阅HTTPAsyncFileResponse类，了解如何执行此操作的示例。
 
 HTTPConnection在响应请求时的正常事件流程如下：
 发送HTTP响应头
 通过readDataOfLength方法从响应获取数据
 将数据添加到asyncSocket的写入队列
 等待asyncSocket通知数据已发送
 通过readDataOfLength方法从响应获取更多数据
 ...继续此循环，直到整个响应发送完毕
 
 
 对于异步响应，流程略有不同。
 首先，HTTPResponse有机会推迟发送HTTP响应头。
 这允许响应异步执行任何代码，以计算头的一部分。例如，响应可能需要生成一些自定义的头字段，
 或者响应可能需要在网络附加存储上查找资源。由于网络附加存储可能较慢，响应不知道是发送200还是404。
 在这种情况下，HTTPResponse只需实现delayResponseHeaders方法并返回YES。从此方法返回YES后，
 HTTPConnection将等到响应调用其responseHasAvailableData方法。此发生后，HTTPConnection将再次查询delayResponseHeaders方法，
 以查看响应是否准备好发送头。
 
 此循环将继续，直到delayResponseHeaders方法返回NO。
 
 您应该只在关于头的一切都准备就绪时推迟发送响应头。
 异步生成响应主体不能成为推迟发送头的借口。
 在发送响应头后，HTTPConnection调用您的readDataOfLength方法。
 此时可能有可用数据，也可能没有。如果没有，请简单地返回nil。
 在生成新数据时，应稍后调用HTTPConnection的responseHasAvailableData。
 您无需跟踪何时在readDataOfLength方法中返回nil，或者调用了多少次responseHasAvailableData。
 只需在生成新数据时调用responseHasAvailableData，而在所请求范围内的readDataOfLength中没有可用数据时返回nil。
 HTTPConnection将自动检测何时应请求新数据，并采取相应措施。
 还需注意HTTP服务器支持范围请求。
 setOffset方法是强制性的，不能忽略。确保在readDataOfLength方法中考虑偏移量。
 还应该知道，HTTPConnection会自动对任何范围请求进行排序。
 因此，如果setOffset方法以值100被调用，那么可以安全地释放字节0-99。
 HTTPConnection还可以帮助您保持内存占用较小。
 想象一下，您动态生成了一个10 MB的响应。您可能不想将所有这些数据加载到RAM中，
 并坐在那里等待HTTPConnection缓慢地将其通过网络发送出去。您只需要注意HTTPConnection通过readDataOfLength请求更多数据的时机。
 这是因为HTTPConnection永远不会允许asyncSocket的写入队列变得比READ_CHUNKSIZE字节大得多。
 您应该考虑如何利用这个事实，按需生成异步响应，同时保持内存占用较小，使应用程序运行迅捷。
 如果不提前知道content-length，您还应该实现isChunked方法。
 这意味着响应不会包含Content-Length头，而是使用"Transfer-Encoding: chunked"。
 如果响应是异步且动态的，有很大可能它也是分块的。
 如果响应是分块的，您无需担心范围请求。
 */
