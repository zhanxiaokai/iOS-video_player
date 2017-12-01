//
//  VideoPlayerViewController.h
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AVSynchronizer.h"
#import "VideoOutput.h"
#import "AudioOutput.h"

@interface VideoPlayerViewController : UIViewController

@property(nonatomic, retain) AVSynchronizer*                synchronizer;
@property(nonatomic, retain) NSString*                      videoFilePath;
@property(nonatomic, weak) id<PlayerStateDelegate>          playerStateDelegate;


+ (instancetype)viewControllerWithContentPath:(NSString *)path
                            contentFrame:(CGRect)frame
                            playerStateDelegate:(id) playerStateDelegate
                            parameters: (NSDictionary *)parameters;

+ (instancetype)viewControllerWithContentPath:(NSString *)path
                                 contentFrame:(CGRect)frame
                          playerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate
                                   parameters: (NSDictionary *)parameters
                  outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

- (instancetype) initWithContentPath:(NSString *)path
              contentFrame:(CGRect)frame
       playerStateDelegate:(id) playerStateDelegate
                parameters:(NSDictionary *)parameters;

- (instancetype) initWithContentPath:(NSString *)path
                        contentFrame:(CGRect)frame
                 playerStateDelegate:(id) playerStateDelegate
                          parameters:(NSDictionary *)parameters
         outputEAGLContextShareGroup:(EAGLSharegroup *)sharegroup;

- (void)play;

- (void)pause;

- (void)stop;

- (void) restart;

- (BOOL) isPlaying;

- (UIImage *)movieSnapshot;

- (VideoOutput*) createVideoOutputInstance;
- (VideoOutput*) getVideoOutputInstance;
@end
