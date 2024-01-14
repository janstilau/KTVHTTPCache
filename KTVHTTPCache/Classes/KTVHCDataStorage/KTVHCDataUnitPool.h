//
//  KTVHCDataUnitPool.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCDataUnit.h"
#import "KTVHCDataCacheItem.h"

@interface KTVHCDataUnitPool : NSObject

// 只可以使用 pool 这种方式, 可以使用 NS_UNAVAILABLE 明确的告知, 不能使用一般的初始化. 
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)pool;

- (KTVHCDataUnit *)unitWithURL:(NSURL *)URL;

- (long long)totalCacheLength;

- (NSArray<KTVHCDataCacheItem *> *)allCacheItem;
- (KTVHCDataCacheItem *)cacheItemWithURL:(NSURL *)URL;

- (void)deleteUnitWithURL:(NSURL *)URL;
- (void)deleteUnitsWithLength:(long long)length;
- (void)deleteAllUnits;

@end
