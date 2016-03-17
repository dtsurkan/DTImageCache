//
//  DTImageCache.h
//  DTImageCache
//
//  Created by Dmitriy Tsurkan on 3/17/16.
//  Copyright © 2016 Dmitriy Tsurkan. All rights reserved.
//

@import Foundation;
@import UIKit;

@interface DTImageCache : NSCache

+ (nonnull DTImageCache *)sharedInstance;
- (void)bluredImageForImage:(nonnull UIImage *)image withSize:(CGSize)size forKey:(nonnull NSString *)key completionBlock:(void ( ^ _Nullable )( UIImage * _Nonnull image))completion;
+ (nonnull NSString *)SHA1FromString:(nonnull NSString *)string;

@end
