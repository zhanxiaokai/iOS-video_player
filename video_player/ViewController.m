//
//  ViewController.m
//  video_player
//
//  Created by apple on 2017/7/11.
//  Copyright © 2017年 xiaokai.zhan. All rights reserved.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "ELVideoViewPlayerController.h"

NSString * const MIN_BUFFERED_DURATION = @"Min Buffered Duration";
NSString * const MAX_BUFFERED_DURATION = @"Max Buffered Duration";

@interface ViewController ()
{
    NSMutableDictionary*            _requestHeader;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Changba Player";
    _requestHeader = [NSMutableDictionary dictionary];
    _requestHeader[MIN_BUFFERED_DURATION] = @(1.0f);
    _requestHeader[MAX_BUFFERED_DURATION] = @(3.0f);
    // Do any additional setup after loading the view, typically from a nib.
    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_main_queue() ,^{
        NSLog(@"5");
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"4");
    });
    [self performSelector:@selector(test2)];
    [self performSelector:@selector(test3) withObject:nil afterDelay:0];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"6");
    });
    [self test1];
}
- (void) test3{
    NSLog(@"3");
}
- (void) test2{
    NSLog(@"2");
}
- (void) test1 {
    NSLog(@"1");
}
- (IBAction)forwardToPlayer:(id)sender {
    NSLog(@"forward local player page...");
    NSString* videoFilePath = [CommonUtil bundlePath:@"recording.flv"];
//    videoFilePath = @"http://wspull01.live.changbalive.com/easylive/1709828.flv";
    videoFilePath = [CommonUtil bundlePath:@"test-1.flv"];
    BOOL usingHWCodec = YES;
    ELVideoViewPlayerController *vc = [ELVideoViewPlayerController viewControllerWithContentPath:videoFilePath contentFrame:self.view.bounds parameters:_requestHeader];
    [[self navigationController] pushViewController:vc animated:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
