//
//  ViewController.m
//  DTImageCache
//
//  Created by Dmitriy Tsurkan on 3/17/16.
//  Copyright © 2016 Dmitriy Tsurkan. All rights reserved.
//

#import "ViewController.h"
#import "DTImageCache.h"


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSURL *imageURL = [NSURL URLWithString:@"https://cdn.photographylife.com/wp-content/uploads/2014/06/Nikon-D810-Image-Sample-6.jpg"];
  
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:imageURL];
        UIImage *image = [[UIImage alloc] initWithData:data];
                    
            [[DTImageCache sharedInstance] bluredImageForImage:image withSize:self.imageView.frame.size forKey:@"1234" completionBlock:^(UIImage * _Nonnull image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.imageView.image = image;
                });
            }];
            
        
    });
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
