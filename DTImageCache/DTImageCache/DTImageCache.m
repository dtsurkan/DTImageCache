//
//  DTImageCache.m
//  DTImageCache
//
//  Created by Dmitriy Tsurkan on 3/17/16.
//  Copyright © 2016 Dmitriy Tsurkan. All rights reserved.
//

#import "DTImageCache.h"
#import <CommonCrypto/CommonDigest.h>

static inline NSString *DTImageCacheDirectory() {
    static NSString *_DTImageCacheDirectory;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _DTImageCacheDirectory = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/DTCache"] copy];
    });
    
    return _DTImageCacheDirectory;
}

inline static NSString *keyForURL(NSURL *url) {
    return [url absoluteString];
}

static inline NSString *cachePathForKey(NSString *key) {
    NSString *fileName = [NSString stringWithFormat:@"DTImageCache-%@", [DTImageCache SHA1FromString:key]];
    return [DTImageCacheDirectory() stringByAppendingPathComponent:fileName];
}

@interface DTImageCache ()

@property (strong, nonatomic) NSOperationQueue *diskOperationQueue;

@end


float const kMenuIconBlurRadius = 32.0;




@implementation DTImageCache

static DTImageCache *sharedInstance;

+ (nonnull DTImageCache *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DTImageCache alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.diskOperationQueue = [[NSOperationQueue alloc] init];
        [[NSFileManager defaultManager] createDirectoryAtPath:DTImageCacheDirectory()
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return self;
}

- (void)bluredImageForImage:(nonnull UIImage *)image withSize:(CGSize)size forKey:(nonnull NSString *)key completionBlock:(void (^)(UIImage *image))completion {
    if (!key) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *displayImage = [self cachedImageForKey:key];
        
        if (displayImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(displayImage);
            });
        } else {
            NSString *cachePath = cachePathForKey(key);
            NSInvocation *writeInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(writeData:toPath:)]];
            
            displayImage = [self blurImage:image forSize:size];
            NSData *data = UIImagePNGRepresentation(displayImage);
            
            [writeInvocation setTarget:self];
            [writeInvocation setSelector:@selector(writeData:toPath:)];
            [writeInvocation setArgument:&data atIndex:2];
            [writeInvocation setArgument:&cachePath atIndex:3];

            
            [self performDiskWriteOperation:writeInvocation];
            [self setImage:displayImage forKey:key];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(displayImage);
            });
        }
    });
}

- (void)removeAllObjects {
    [super removeAllObjects];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:DTImageCacheDirectory() error:&error];
        
        if (error == nil) {
            for (NSString *path in directoryContents) {
                NSString *fullPath = [DTImageCacheDirectory() stringByAppendingPathComponent:path];
                
                BOOL removeSuccess = [fileMgr removeItemAtPath:fullPath error:&error];
                if (!removeSuccess) {
                    //Error Occured
                }
            }
        } else {
            //Error Occured
        }
    });
}

- (void)removeObjectForKey:(id)key {
    [super removeObjectForKey:key];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSString *cachePath = cachePathForKey(key);
        
        NSError *error = nil;
        
        BOOL removeSuccess = [fileMgr removeItemAtPath:cachePath error:&error];
        if (!removeSuccess) {
            //Error Occured
        }
    });
}

#pragma mark Getter Methods
- (UIImage *) cachedImageForKey:(NSString *)key {
    if(!key) return nil;
    
    id returner = [super objectForKey:key];
    
    if (returner) {
        return returner;
    } else {
        UIImage *i = [self imageFromDiskForKey:key];
        if (i) {
            [self setImage:i forKey:key];
        };
        
        return i;
    }
    
    return nil;
}

- (UIImage *)cachedImageForURL:(NSURL *)url {
    NSString *key = keyForURL(url);
    return [self cachedImageForKey:key];
}


- (UIImage *)imageFromDiskForKey:(NSString *)key {
    NSData *data = [NSData dataWithContentsOfFile:cachePathForKey(key)];
    UIImage *i = [[UIImage alloc] initWithData:data];
    return i;
}

- (UIImage *)imageFromDiskForURL:(NSURL *)url {
    return [self imageFromDiskForKey:keyForURL(url)];
}


#pragma mark Setter Methods

- (void)setImage:(UIImage *)i forKey:(NSString *)key {
    if (i) {
        [super setObject:i forKey:key];
    }
}

- (void) setImage:(UIImage *)i forURL:(NSURL *)url {
    [self setImage:i forKey:keyForURL(url)];
}

- (void)removeImageForKey:(NSString *)key {
    [self removeObjectForKey:key];
}

- (void)removeImageForURL:(NSURL *)url {
    [self removeImageForKey:keyForURL(url)];
}


#pragma mark - Helpers

- (void)writeData:(NSData *)data toPath:(NSString *)path {
    [data writeToFile:path atomically:YES];
}

- (void)performDiskWriteOperation:(NSInvocation *)invoction {
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithInvocation:invoction];
    [self.diskOperationQueue addOperation:operation];
}

+ (NSString *)SHA1FromString:(NSString *)string {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    
    NSData *stringBytes = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    if (CC_SHA1([stringBytes bytes], (CC_LONG)[stringBytes length], digest)) {
        
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
        
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            [output appendFormat:@"%02x", digest[i]];
        }
        
        return output;
    }
    return nil;
}

- (UIImage *)blurImage:(UIImage *)image forSize:(CGSize)size {
    image = [self imageFromImage:image scaledToFitInSize:size];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:kMenuIconBlurRadius] forKey:@"inputRadius"];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    
    CGImageRef cgImage = [context createCGImage:result fromRect:[inputImage extent]];
    
    UIImage *returnImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return returnImage;
}

- (UIImage *)imageFromImage:(UIImage *)image scaledToFitInSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    [image drawInRect:CGRectMake(kMenuIconBlurRadius, kMenuIconBlurRadius, size.width - kMenuIconBlurRadius * 2.0, size.height - kMenuIconBlurRadius * 2.0)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
