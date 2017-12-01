//
//  AVSynchronizer.h
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "VideoDecoder.h"

#define TIMEOUT_DECODE_ERROR            20
#define TIMEOUT_BUFFER                  10

extern NSString * const kMIN_BUFFERED_DURATION;
extern NSString * const kMAX_BUFFERED_DURATION;

typedef enum OpenState{
    OPEN_SUCCESS,
    OPEN_FAILED,
    CLIENT_CANCEL,
} OpenState;

@protocol PlayerStateDelegate <NSObject>

- (void) openSucceed;

- (void) connectFailed;

- (void) hideLoading;

- (void) showLoading;

- (void) onCompletion;

- (void) buriedPointCallback:(BuriedPoint*) buriedPoint;

- (void) restart;

@end

@interface AVSynchronizer : NSObject

@property (nonatomic, weak) id<PlayerStateDelegate> playerStateDelegate;

- (id) initWithPlayerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate;

- (OpenState) openFile: (NSString *) path
            parameters:(NSDictionary*) parameters error: (NSError **) perror;

- (OpenState) openFile: (NSString *) path 
                 error: (NSError **) perror;

- (void) closeFile;


- (void) audioCallbackFillData: (SInt16 *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels;

- (VideoFrame*) getCorrectVideoFrame;

- (void) run;
- (BOOL) isOpenInputSuccess;
- (void) interrupt;

- (BOOL) usingHWCodec;

- (BOOL) isPlayCompleted;

- (NSInteger) getAudioSampleRate;
- (NSInteger) getAudioChannels;
- (CGFloat) getVideoFPS;
- (NSInteger) getVideoFrameHeight;
- (NSInteger) getVideoFrameWidth;
- (BOOL) isValid;
- (CGFloat) getDuration;

@end
