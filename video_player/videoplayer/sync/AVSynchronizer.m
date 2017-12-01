//
//  AVSynchronizer.m
//  video_player
//
//  Created by apple on 16/8/25.
//  Copyright © 2016年 xiaokai.zhan. All rights reserved.
//

#import "AVSynchronizer.h"
#import "VideoDecoder.h"
#import <UIKit/UIDevice.h>
#import <pthread.h>

#define LOCAL_MIN_BUFFERED_DURATION                     0.5
#define LOCAL_MAX_BUFFERED_DURATION                     1.0
#define NETWORK_MIN_BUFFERED_DURATION                   2.0
#define NETWORK_MAX_BUFFERED_DURATION                   4.0
#define LOCAL_AV_SYNC_MAX_TIME_DIFF                     0.05
#define FIRST_BUFFER_DURATION                           0.5

NSString * const kMIN_BUFFERED_DURATION = @"Min_Buffered_Duration";
NSString * const kMAX_BUFFERED_DURATION = @"Max_Buffered_Duration";

@interface AVSynchronizer () {
    
    VideoDecoder*                                       _decoder;
    BOOL                                                isOnDecoding;
    BOOL                                                isInitializeDecodeThread;
    BOOL                                                isDestroyed;
    
    BOOL                                                isFirstScreen;
    /** 解码第一段buffer的控制变量 **/
    pthread_mutex_t                                     decodeFirstBufferLock;
    pthread_cond_t                                      decodeFirstBufferCondition;
    pthread_t                                           decodeFirstBufferThread;
    /** 是否正在解码第一段buffer **/
    BOOL                                                isDecodingFirstBuffer;
    
    pthread_mutex_t                                     videoDecoderLock;
    pthread_cond_t                                      videoDecoderCondition;
    pthread_t                                           videoDecoderThread;
    
//    dispatch_queue_t                                    _dispatchQueue;
    NSMutableArray*                                     _videoFrames;
    NSMutableArray*                                     _audioFrames;
    
    /** 分别是当外界需要音频数据和视频数据的时候, 全局变量缓存数据 **/
    NSData*                                             _currentAudioFrame;
    NSUInteger                                          _currentAudioFramePos;
    CGFloat                                             _audioPosition;
    VideoFrame*                                         _currentVideoFrame;
    
    /** 控制何时该解码 **/
    BOOL                                                _buffered;
    CGFloat                                             _bufferedDuration;
    CGFloat                                             _minBufferedDuration;
    CGFloat                                             _maxBufferedDuration;
    
    CGFloat                                             _syncMaxTimeDiff;
    NSInteger                                           _firstBufferDuration;
    
    BOOL                                                _completion;
    
    NSTimeInterval                                      _bufferedBeginTime;
    NSTimeInterval                                      _bufferedTotalTime;
    
    int                                                 _decodeVideoErrorState;
    NSTimeInterval                                      _decodeVideoErrorBeginTime;
    NSTimeInterval                                      _decodeVideoErrorTotalTime;
}

@end

@implementation AVSynchronizer

static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

static void* runDecoderThread(void* ptr)
{
    AVSynchronizer* synchronizer = (__bridge AVSynchronizer*)ptr;
    [synchronizer run];
    return NULL;
}

- (BOOL) isPlayCompleted;
{
    return _completion;
}

- (void) run
{
    while(isOnDecoding){
        pthread_mutex_lock(&videoDecoderLock);
//        NSLog(@"Before wait First decode Buffer...");
        pthread_cond_wait(&videoDecoderCondition, &videoDecoderLock);
//        NSLog(@"After wait First decode Buffer...");
        pthread_mutex_unlock(&videoDecoderLock);
        //			LOGI("after pthread_cond_wait");
        [self decodeFrames];
    }
}

static void* decodeFirstBufferRunLoop(void* ptr)
{
    AVSynchronizer* synchronizer = (__bridge AVSynchronizer*)ptr;
    [synchronizer decodeFirstBuffer];
    return NULL;
}

- (void) decodeFirstBuffer
{
    double startDecodeFirstBufferTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
    [self decodeFramesWithDuration:FIRST_BUFFER_DURATION];
    int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startDecodeFirstBufferTimeMills;
    NSLog(@"Decode First Buffer waste TimeMills is %d", wasteTimeMills);
    pthread_mutex_lock(&decodeFirstBufferLock);
    pthread_cond_signal(&decodeFirstBufferCondition);
    pthread_mutex_unlock(&decodeFirstBufferLock);
    isDecodingFirstBuffer = false;
}

- (void) decodeFramesWithDuration:(CGFloat) duration;
{
    BOOL good = YES;
    while (good) {
        good = NO;
        @autoreleasepool {
            if (_decoder && (_decoder.validVideo || _decoder.validAudio)) {
                int tmpDecodeVideoErrorState;
                NSArray *frames = [_decoder decodeFrames:0.0f decodeVideoErrorState:&tmpDecodeVideoErrorState];
                if (frames.count) {
                    good = [self addFrames:frames duration:duration];
                }
            }
        }
    }
}

- (void) decodeFrames
{
    const CGFloat duration = 0.0f;
    BOOL good = YES;
    while (good) {
        good = NO;
        @autoreleasepool {
            if (_decoder && (_decoder.validVideo || _decoder.validAudio)) {
                NSArray *frames = [_decoder decodeFrames:duration decodeVideoErrorState:&_decodeVideoErrorState];
                if (frames.count) {
                    good = [self addFrames:frames duration:_maxBufferedDuration];
                }
            }
        }
    }
}

- (id) initWithPlayerStateDelegate:(id<PlayerStateDelegate>) playerStateDelegate
{
    self = [super init];
    if (self) {
        _playerStateDelegate = playerStateDelegate;
    }
    return self;
}

- (void) signalDecoderThread
{
    if(NULL == _decoder || isDestroyed) {
        return;
    }
    if(!isDestroyed) {
        pthread_mutex_lock(&videoDecoderLock);
//        NSLog(@"Before signal First decode Buffer...");
        pthread_cond_signal(&videoDecoderCondition);
//        NSLog(@"After signal First decode Buffer...");
        pthread_mutex_unlock(&videoDecoderLock);
    }
}

- (OpenState) openFile: (NSString *) path usingHWCodec: (BOOL) usingHWCodec error: (NSError **) perror;
{
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    parameters[FPS_PROBE_SIZE_CONFIGURED] = @(true);
    parameters[PROBE_SIZE] = @(50 * 1024);
    NSMutableArray* durations = [NSMutableArray array];
    durations[0] = @(1250000);
    durations[0] = @(1750000);
    durations[0] = @(2000000);
    parameters[MAX_ANALYZE_DURATION_ARRAY] = durations;
    return [self openFile:path parameters:parameters error:perror];
}

- (OpenState) openFile: (NSString *) path parameters:(NSDictionary*) parameters error: (NSError **) perror;
{
    //1、创建decoder实例
    [self createDecoderInstance];
    //2、初始化成员变量
    _currentVideoFrame = NULL;
    _currentAudioFramePos = 0;
    
    _bufferedBeginTime = 0;
    _bufferedTotalTime = 0;
    
    _decodeVideoErrorBeginTime = 0;
    _decodeVideoErrorTotalTime = 0;
    isFirstScreen = YES;
    
    _minBufferedDuration = [parameters[kMIN_BUFFERED_DURATION] floatValue];
    _maxBufferedDuration = [parameters[kMAX_BUFFERED_DURATION] floatValue];
    
    BOOL isNetwork = isNetworkPath(path);
    if (ABS(_minBufferedDuration - 0.f) < CGFLOAT_MIN) {
        if(isNetwork){
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
        } else{
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
        }
    }
    
    if ((ABS(_maxBufferedDuration - 0.f) < CGFLOAT_MIN)) {
        if(isNetwork){
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
        } else{
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
    }
    
    if (_minBufferedDuration > _maxBufferedDuration) {
        float temp = _minBufferedDuration;
        _minBufferedDuration = _maxBufferedDuration;
        _maxBufferedDuration = temp;
    }
    
    _syncMaxTimeDiff = LOCAL_AV_SYNC_MAX_TIME_DIFF;
    _firstBufferDuration = FIRST_BUFFER_DURATION;
    //3、打开流并且解析出来音视频流的Context
    BOOL openCode = [_decoder openFile:path parameter:parameters error:perror];
    if(!openCode || ![_decoder isSubscribed] || isDestroyed){
        NSLog(@"VideoDecoder decode file fail...");
        [self closeDecoder];
        return [_decoder isSubscribed] ? OPEN_FAILED : CLIENT_CANCEL;
    }
    //4、回调客户端视频宽高以及duration
    NSUInteger videoWidth = [_decoder frameWidth];
    NSUInteger videoHeight = [_decoder frameHeight];
    if(videoWidth <= 0 || videoHeight <= 0){
        return [_decoder isSubscribed] ? OPEN_FAILED : CLIENT_CANCEL;
    }
    //5、开启解码线程与解码队列
    _audioFrames        = [NSMutableArray array];
    _videoFrames        = [NSMutableArray array];
    [self startDecoderThread];
    [self startDecodeFirstBufferThread];
    return OPEN_SUCCESS;
}

- (void) startDecodeFirstBufferThread
{
    pthread_mutex_init(&decodeFirstBufferLock, NULL);
    pthread_cond_init(&decodeFirstBufferCondition, NULL);
    isDecodingFirstBuffer = true;
    
    pthread_create(&decodeFirstBufferThread, NULL, decodeFirstBufferRunLoop, (__bridge void*)self);
}

- (void) startDecoderThread {
    NSLog(@"AVSynchronizer::startDecoderThread ...");
    //    _dispatchQueue      = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
    
    isOnDecoding = true;
    isDestroyed = false;
    pthread_mutex_init(&videoDecoderLock, NULL);
    pthread_cond_init(&videoDecoderCondition, NULL);
    isInitializeDecodeThread = true;
    pthread_create(&videoDecoderThread, NULL, runDecoderThread, (__bridge void*)self);
}

static int count = 0;
static int invalidGetCount = 0;
float lastPosition = -1.0;

- (VideoFrame*) getCorrectVideoFrame;
{
    VideoFrame *frame = NULL;
    @synchronized(_videoFrames) {
        while (_videoFrames.count > 0) {
            frame = _videoFrames[0];
            const CGFloat delta = _audioPosition - frame.position;
            if (delta < (0 - _syncMaxTimeDiff)) {
//                NSLog(@"视频比音频快了好多,我们还是渲染上一帧");
                frame = NULL;
                break;
            }
            [_videoFrames removeObjectAtIndex:0];
            if (delta > _syncMaxTimeDiff) {
//                NSLog(@"视频比音频慢了好多,我们需要继续从queue拿到合适的帧 _audioPosition is %.3f frame.position %.3f", _audioPosition, frame.position);
                frame = NULL;
                continue;
            } else {
                break;
            }
        }
    }
    if (frame) {
        if (isFirstScreen) {
            [_decoder triggerFirstScreen];
            isFirstScreen = NO;
        }
//        NSLog(@"frame is Not NUll position is %.3f", frame.position);
        if (NULL != _currentVideoFrame) {
            _currentVideoFrame = NULL;
        }
        _currentVideoFrame = frame;
    } else{
//        NSLog(@"frame is NULL");
    }
//    if(NULL != _currentVideoFrame){
//        NSLog(@"audio played position is %.3f _currentVideoFrame position is %.3f", _audioPosition, _currentVideoFrame.position);
//    }
    
    if(fabs(_currentVideoFrame.position - lastPosition) > 0.01f){
//        NSLog(@"lastPosition is %.3f _currentVideoFrame position is %.3f", lastPosition, _currentVideoFrame.position);
        lastPosition = _currentVideoFrame.position;
        count++;
        return _currentVideoFrame;
    } else {
        invalidGetCount++;
        return nil;
    }
}

- (void) audioCallbackFillData: (SInt16 *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels;
{
    [self checkPlayState];
    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
        return;
    }
    @autoreleasepool {
        while (numFrames > 0) {
            if (!_currentAudioFrame) {
                //从队列中取出音频数据
                @synchronized(_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    if (count > 0) {
                        AudioFrame *frame = _audioFrames[0];
                        _bufferedDuration -= frame.duration;
                        
                        [_audioFrames removeObjectAtIndex:0];
                        _audioPosition = frame.position;
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(SInt16);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
                
            } else {
                memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
                break;
            }
        }
    }
}

- (void)checkPlayState;
{
    if (NULL == _decoder) {
        return;
    }
    if (_buffered && ((_bufferedDuration > _minBufferedDuration))) {
        _buffered = NO;
        if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(hideLoading)]){
            [_playerStateDelegate hideLoading];
        }
    }
    if (1 == _decodeVideoErrorState) {
        _decodeVideoErrorState = 0;
        if (_minBufferedDuration > 0 && !_buffered) {
            _buffered = YES;
            _decodeVideoErrorBeginTime = [[NSDate date] timeIntervalSince1970];
        }
        
        _decodeVideoErrorTotalTime = [[NSDate date] timeIntervalSince1970] - _decodeVideoErrorBeginTime;
        if (_decodeVideoErrorTotalTime > TIMEOUT_DECODE_ERROR) {
            NSLog(@"decodeVideoErrorTotalTime = %f", _decodeVideoErrorTotalTime);
            _decodeVideoErrorTotalTime = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"restart after decodeVideoError");
                if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(restart)]){
                    [_playerStateDelegate restart];
                }
            });
        }
        return;
    }
    const NSUInteger leftVideoFrames = _decoder.validVideo ? _videoFrames.count : 0;
    const NSUInteger leftAudioFrames = _decoder.validAudio ? _audioFrames.count : 0;
    if (0 == leftVideoFrames || 0 == leftAudioFrames) {
        //Buffer Status Empty Record
        [_decoder addBufferStatusRecord:@"E"];
        if (_minBufferedDuration > 0 && !_buffered) {
            _buffered = YES;
            _bufferedBeginTime = [[NSDate date] timeIntervalSince1970];
            if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(showLoading)]){
                [_playerStateDelegate showLoading];
            }
        }
        if([_decoder isEOF]){
            if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(onCompletion)]){
                _completion = YES;
                [_playerStateDelegate onCompletion];
            }
        }
    }
    
    if (_buffered) {
        _bufferedTotalTime = [[NSDate date] timeIntervalSince1970] - _bufferedBeginTime;
        if (_bufferedTotalTime > TIMEOUT_BUFFER) {
            _bufferedTotalTime = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
#ifdef DEBUG
                NSLog(@"AVSynchronizer restart after timeout");
#endif
                if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(restart)]){
                    NSLog(@"=============================== AVSynchronizer restart");
                    [_playerStateDelegate restart];
                }
            });
            return;
        }
    }
    
    if (!isDecodingFirstBuffer && (0 == leftVideoFrames || 0 == leftAudioFrames || !(_bufferedDuration > _minBufferedDuration))) {
#ifdef DEBUG
//        NSLog(@"AVSynchronizer _bufferedDuration is %.3f _minBufferedDuration is %.3f", _bufferedDuration, _minBufferedDuration);
#endif
        [self signalDecoderThread];
    } else if(_bufferedDuration >= _maxBufferedDuration) {
        //Buffer Status Full Record
        [_decoder addBufferStatusRecord:@"F"];
    }
}

- (BOOL) addFrames: (NSArray *)frames duration:(CGFloat) duration
{
    if (_decoder.validVideo) {
        @synchronized(_videoFrames) {
            for (Frame *frame in frames)
                if (frame.type == VideoFrameType) {
                    [_videoFrames addObject:frame];
                }
        }
    }
    
    if (_decoder.validAudio) {
        @synchronized(_audioFrames) {
            for (Frame *frame in frames)
                if (frame.type == AudioFrameType) {
                    [_audioFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
        }
    }
    return _bufferedDuration < duration;
}

- (void) createDecoderInstance
{
    _decoder = [[VideoDecoder alloc] init];
}

- (BOOL) isOpenInputSuccess
{
    BOOL ret = NO;
    if (_decoder){
        ret = [_decoder isOpenInputSuccess];
    }
    return ret;
}

- (void) interrupt
{
    if (_decoder){
        [_decoder interrupt];
    }
}

- (void) closeFile;
{
    if (_decoder){
        [_decoder interrupt];
    }
    [self destroyDecodeFirstBufferThread];
    [self destroyDecoderThread];
    if([_decoder isOpenInputSuccess]){
        [self closeDecoder];
    }
    
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    NSLog(@"present diff video frame cnt is %d invalidGetCount is %d", count, invalidGetCount);
}

- (void) closeDecoder;
{
    if(_decoder){
        [_decoder closeFile];
        if(_playerStateDelegate && [_playerStateDelegate respondsToSelector:@selector(buriedPointCallback:)]){
            [_playerStateDelegate buriedPointCallback:[_decoder getBuriedPoint]];
        }
        _decoder = nil;
    }
}

- (void) destroyDecodeFirstBufferThread {
    if (isDecodingFirstBuffer) {
        NSLog(@"Begin Wait Decode First Buffer...");
        double startWaitDecodeFirstBufferTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
        pthread_mutex_lock(&decodeFirstBufferLock);
        pthread_cond_wait(&decodeFirstBufferCondition, &decodeFirstBufferLock);
        pthread_mutex_unlock(&decodeFirstBufferLock);
        int wasteTimeMills = CFAbsoluteTimeGetCurrent() * 1000 - startWaitDecodeFirstBufferTimeMills;
        NSLog(@" Wait Decode First Buffer waste TimeMills is %d", wasteTimeMills);
    }
}

- (void) destroyDecoderThread {
    NSLog(@"AVSynchronizer::destroyDecoderThread ...");
    //    if(_dispatchQueue){
    //        _dispatchQueue = nil;
    //    }
    
    isDestroyed = true;
    isOnDecoding = false;
    if (!isInitializeDecodeThread) {
        return;
    }
    
    void* status;
    pthread_mutex_lock(&videoDecoderLock);
    pthread_cond_signal(&videoDecoderCondition);
    pthread_mutex_unlock(&videoDecoderLock);
    pthread_join(videoDecoderThread, &status);
    pthread_mutex_destroy(&videoDecoderLock);
    pthread_cond_destroy(&videoDecoderCondition);
}

- (NSInteger) getAudioSampleRate;
{
    if (_decoder) {
        return [_decoder sampleRate];
    }
    return -1;
}

- (NSInteger) getAudioChannels;
{
    if (_decoder) {
        return [_decoder channels];
    }
    return -1;
}

- (CGFloat) getVideoFPS;
{
    if (_decoder) {
        return [_decoder getVideoFPS];
    }
    return 0.0f;
}

- (NSInteger) getVideoFrameHeight;
{
    if (_decoder) {
        return [_decoder frameHeight];
    }
    return 0;
}

- (NSInteger) getVideoFrameWidth;
{
    if (_decoder) {
        return [_decoder frameWidth];
    }
    return 0;
}

- (BOOL) isValid;
{
    if(_decoder && ![_decoder validVideo] && ![_decoder validAudio]){
        return NO;
    }
    return YES;
}

- (CGFloat) getDuration;
{
    if (_decoder) {
        return [_decoder getDuration];
    }
    return 0.0f;
}

- (void) dealloc;
{
    NSLog(@"AVSynchronizer Dealloc...");
}
@end
