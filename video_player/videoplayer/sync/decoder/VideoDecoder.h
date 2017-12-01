//
//  VideoDecoder.h
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CVImageBuffer.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/pixdesc.h"

typedef enum {
    AudioFrameType,
    VideoFrameType,
} FrameType;

@interface BuriedPoint : NSObject
@property (readwrite, nonatomic) long long beginOpen;              // 开始试图去打开一个直播流的绝对时间
@property (readwrite, nonatomic) float successOpen;                // 成功打开流花费时间
@property (readwrite, nonatomic) float firstScreenTimeMills;       // 首屏时间
@property (readwrite, nonatomic) float failOpen;                   // 流打开失败花费时间
@property (readwrite, nonatomic) float failOpenType;               // 流打开失败类型
@property (readwrite, nonatomic) int retryTimes;                   // 打开流重试次数
@property (readwrite, nonatomic) float duration;                   // 拉流时长
@property (readwrite, nonatomic) NSMutableArray* bufferStatusRecords; // 拉流状态


@end

@interface Frame : NSObject
@property (readwrite, nonatomic) FrameType type;
@property (readwrite, nonatomic) CGFloat position;
@property (readwrite, nonatomic) CGFloat duration;
@end

@interface AudioFrame : Frame
@property (readwrite, nonatomic, strong) NSData *samples;
@end

@interface VideoFrame : Frame
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@property (readwrite, nonatomic) NSUInteger linesize;
@property (readwrite, nonatomic, strong) NSData *luma;
@property (readwrite, nonatomic, strong) NSData *chromaB;
@property (readwrite, nonatomic, strong) NSData *chromaR;
@property (readwrite, nonatomic, strong) id imageBuffer;
@end

#ifndef SUBSCRIBE_VIDEO_DATA_TIME_OUT
#define SUBSCRIBE_VIDEO_DATA_TIME_OUT               20
#endif
#ifndef NET_WORK_STREAM_RETRY_TIME
#define NET_WORK_STREAM_RETRY_TIME                  3
#endif
#ifndef RTMP_TCURL_KEY
#define RTMP_TCURL_KEY                              @"RTMP_TCURL_KEY"
#endif

#ifndef FPS_PROBE_SIZE_CONFIGURED
#define FPS_PROBE_SIZE_CONFIGURED                   @"FPS_PROBE_SIZE_CONFIGURED"
#endif
#ifndef PROBE_SIZE
#define PROBE_SIZE                                  @"PROBE_SIZE"
#endif
#ifndef MAX_ANALYZE_DURATION_ARRAY
#define MAX_ANALYZE_DURATION_ARRAY                  @"MAX_ANALYZE_DURATION_ARRAY"
#endif

@interface VideoDecoder : NSObject
{
    AVFormatContext*            _formatCtx;
    BOOL                        _isOpenInputSuccess;
    
    BuriedPoint*                _buriedPoint;
    
    int                         totalVideoFramecount;
    long long                   decodeVideoFrameWasteTimeMills;
    
    NSArray*                    _videoStreams;
    NSArray*                    _audioStreams;
    NSInteger                   _videoStreamIndex;
    NSInteger                   _audioStreamIndex;
    AVCodecContext*             _videoCodecCtx;
    AVCodecContext*             _audioCodecCtx;
    CGFloat                     _videoTimeBase;
    CGFloat                     _audioTimeBase;
}

- (BOOL) openFile: (NSString *) path parameter:(NSDictionary*) parameters error: (NSError **) perror;

- (NSArray *) decodeFrames: (CGFloat) minDuration decodeVideoErrorState:(int *)decodeVideoErrorState;

/** 子类重写这两个方法 **/
- (BOOL) openVideoStream;
- (void) closeVideoStream;

- (VideoFrame*) decodeVideo:(AVPacket) packet packetSize:(int) pktSize decodeVideoErrorState:(int *)decodeVideoErrorState;
    
- (void) closeFile;

- (void) interrupt;

- (BOOL) isOpenInputSuccess;

- (void) triggerFirstScreen;
- (void) addBufferStatusRecord:(NSString*) statusFlag;

- (BuriedPoint*) getBuriedPoint;

- (BOOL) detectInterrupted;
- (BOOL) isEOF;
- (BOOL) isSubscribed;
- (NSUInteger) frameWidth;
- (NSUInteger) frameHeight;
- (CGFloat) sampleRate;
- (NSUInteger) channels;
- (BOOL) validVideo;
- (BOOL) validAudio;
- (CGFloat) getVideoFPS;
- (CGFloat) getDuration;
@end
