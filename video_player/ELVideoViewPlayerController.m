//
//  ELVideoViewPlayerController.m
//  video_player
//
//  Created by apple on 16/9/27.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import "ELVideoViewPlayerController.h"
#import "VideoPlayerViewController.h"
#import "LoadingView.h"

@interface ELVideoViewPlayerController() <PlayerStateDelegate>
{
    VideoPlayerViewController*              _playerViewController;
}
@end

@implementation ELVideoViewPlayerController

+ (id)viewControllerWithContentPath:(NSString *)path
                       contentFrame:(CGRect)frame
                         parameters: (NSDictionary *)parameters;
{
    return [[ELVideoViewPlayerController alloc] initWithContentPath:path
                                                     contentFrame:frame 
                                                       parameters: parameters];
}

- (id) initWithContentPath:(NSString *)path
              contentFrame:(CGRect)frame
                parameters:(NSDictionary *)parameters {
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playerViewController = [VideoPlayerViewController viewControllerWithContentPath:path contentFrame:frame playerStateDelegate:self parameters:parameters];
        [self addChildViewController:_playerViewController];
        [self.view addSubview:_playerViewController.view];
    }
    return self;
}

- (void) viewWillDisappear:(BOOL)animated;
{
    [_playerViewController stop];
    [_playerViewController.view removeFromSuperview];
    [_playerViewController removeFromParentViewController];
    //TODO:退出的时候Crash
    [[LoadingView shareLoadingView] close];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if ([_playerViewController isPlaying]) {
        NSLog(@"restart after memorywarning");
        [self restart];
    } else {
        [_playerViewController stop];
    }
}


#pragma mark-Player State Callback
- (void) restart
{
    //Loading 或者 毛玻璃效果在这里处理
    [_playerViewController restart];
}

- (void) connectFailed;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alterView = [[UIAlertView alloc] initWithTitle:@"提示信息" message:@"打开视频失败, 请检查文件或者远程连接是否存在！" delegate:self cancelButtonTitle:@"取消" otherButtonTitles: nil];
        [alterView show];
    });
}

- (void) buriedPointCallback:(BuriedPoint*) buriedPoint;
{
    long long beginOpen = buriedPoint.beginOpen;
    float successOpen = buriedPoint.successOpen;
    float firstScreenTimeMills = buriedPoint.firstScreenTimeMills;
    float failOpen = buriedPoint.failOpen;
    float failOpenType = buriedPoint.failOpenType;
    int retryTimes = buriedPoint.retryTimes;
    float duration = buriedPoint.duration;
    NSMutableArray* bufferStatusRecords = buriedPoint.bufferStatusRecords;
    NSMutableString* buriedPointStatictics = [NSMutableString stringWithFormat:
                                              @"beginOpen : [%lld]", beginOpen];
    [buriedPointStatictics appendFormat:@"successOpen is [%.3f]", successOpen];
    [buriedPointStatictics appendFormat:@"firstScreenTimeMills is [%.3f]", firstScreenTimeMills];
    [buriedPointStatictics appendFormat:@"failOpen is [%.3f]", failOpen];
    [buriedPointStatictics appendFormat:@"failOpenType is [%.3f]", failOpenType];
    [buriedPointStatictics appendFormat:@"retryTimes is [%d]", retryTimes];
    [buriedPointStatictics appendFormat:@"duration is [%.3f]", duration];
    for (NSString* bufferStatus in bufferStatusRecords) {
        [buriedPointStatictics appendFormat:@"buffer status is [%@]", bufferStatus];
    }
    
    NSLog(@"buried point is %@", buriedPointStatictics);
}

- (void) hideLoading
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LoadingView shareLoadingView] close];
    });
}

- (void) showLoading
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LoadingView shareLoadingView] show];
    });
}

- (void) onCompletion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LoadingView shareLoadingView] close];
        UIAlertView *alterView = [[UIAlertView alloc] initWithTitle:@"提示信息" message:@"视频播放完毕了" delegate:self cancelButtonTitle:@"取消" otherButtonTitles: nil];
        [alterView show];
    });
    
}

@end
