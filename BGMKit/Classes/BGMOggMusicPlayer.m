//
//  BGMKitOggMusicPlayer.m
//  BGMKit
//
//  Created by Hunter Bridges on 3/3/16.
//

#import "BGMOggMusicPlayer.h"

static const size_t kOggBufferCount = 3;
static const size_t kOggBufferSize = 1024 * 32;
static const size_t kOggChannels = 2;
static const size_t kOggChanBufferSize = kOggBufferSize / kOggChannels;

@import AVFoundation;

#include "ogg.h"
#include "codec.h"
#include "vorbisenc.h"
#include "vorbisfile.h"

@interface BGMOggMusicPlayer () {
  FILE *_file;
  OggVorbis_File _stream;
  vorbis_info *_vorbisInfo;
  vorbis_comment *_vorbisComment;
}

@property (nonatomic, copy, readwrite) NSString *oggName;
@property (nonatomic, copy, readwrite) NSString *oggPath;
@property (atomic, assign, readwrite) BOOL isPlaying;

@property (nonatomic, assign) BOOL initialized;

@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioPlayerNode *playerNode;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;
@property (atomic, assign) int queueCount;
@property (nonatomic, strong) NSMutableArray *bufferQueue;
@property (nonatomic, strong) NSMutableArray *processedBuffers;

@property (nonatomic, strong) NSThread *decoderThread;
@property (nonatomic, strong) NSCondition *endCondition;
@property (nonatomic, assign) BOOL eof;

@property (nonatomic, strong) CADisplayLink *fadeLink;
@property (nonatomic, assign) CFTimeInterval fadeStartAt;
@property (nonatomic, assign) float fadeFrom;
@property (nonatomic, assign) float fadeTo;
@property (nonatomic, assign) float fadeDuration;
@property (nonatomic, copy) void (^fadeCompletion)();

@end

@implementation BGMOggMusicPlayer

- (id)initWithOGGNamed:(NSString *)name
{
  self = [super init];
  if (self) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"ogg"];
    if (path == nil) {
      [NSException raise:NSInvalidArgumentException format:@"OGG file not found: %@", name, nil];
      return nil;
    }
    
    self.oggName = name;
    self.oggPath = path;
    self.volume = 1.f;
    self.volCoef = 1.f;
  }
  return self;
}

- (void)dealloc
{
  
}

- (void)play
{
  self.isPlaying = YES;
  if (!self.initialized) {
    [self initialize];
  }
}

- (void)stop
{
  [self.playerNode stop];
  [self.engine stop];
  [self.decoderThread cancel];
  [self.endCondition wait];
  [self.endCondition unlock];
  
  self.engine = nil;
  self.playerNode = nil;
  self.mixerNode = nil;
  self.queueCount = 0;
  
  [self closeDecoder];
  
  self.initialized = NO;
}

- (void)pause
{
  self.isPlaying = NO;
}

- (void)fadeTo:(float)coef withDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion
{
  [self clearFadeIfNeeded];
  self.fadeDuration = duration;
  self.fadeFrom = self.volCoef;
  self.fadeTo = coef;
  self.fadeCompletion = completion;
  [self performFade];
}

- (void)fadeInWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion
{
  [self clearFadeIfNeeded];
  self.fadeDuration = duration;
  self.fadeFrom = 0.0f;
  self.fadeTo = 1.0f;
  self.fadeCompletion = completion;
  [self performFade];
}

- (void)fadeOutWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion
{
  [self clearFadeIfNeeded];
  self.fadeDuration = duration;
  self.fadeFrom = self.volCoef;
  self.fadeTo = 0.0f;
  self.fadeCompletion = completion;
  [self performFade];
}

- (BOOL)loop
{
  return YES;
}

- (void)setVolume:(float)volume
{
  _volume = volume;
  [self updateVolume];
}

- (void)setVolCoef:(float)volCoef
{
  _volCoef = volCoef;
  [self updateVolume];
}

#pragma mark - Private

- (void)clearFadeIfNeeded
{
  if (self.fadeLink) {
    [self.fadeLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    if (self.fadeCompletion) {
      self.fadeCompletion();
    }
    self.fadeLink = nil;
    self.fadeCompletion = nil;
  }
}

- (void)performFade
{
  self.volCoef = self.fadeFrom;
  [self updateVolume];
  
  self.fadeLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepFade)];
  self.fadeLink.frameInterval = 2;
  self.fadeStartAt = CACurrentMediaTime();
  [self.fadeLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stepFade
{
  float now = CACurrentMediaTime();
  float p = (now - self.fadeStartAt) / self.fadeDuration;
  float pClamp = MAX(0.0, MIN(p, 1.0));
  
  float delta = self.fadeTo - self.fadeFrom;
  self.volCoef = pClamp * delta + self.fadeFrom;
  [self updateVolume];
  
  if (p >= 1.0) {
    [self.fadeLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    if (self.fadeCompletion) {
      self.fadeCompletion();
    }
    self.fadeLink = nil;
    self.fadeCompletion = nil;
  }
}

- (void)initialize
{
  self.engine = [[AVAudioEngine alloc] init];
  self.playerNode = [[AVAudioPlayerNode alloc] init];
  self.mixerNode = self.engine.mainMixerNode;
  
  [self updateVolume];
  
  [self.engine attachNode:self.playerNode];
  [self.engine connect:self.playerNode to:self.mixerNode format:[self.mixerNode outputFormatForBus:0]];
  
  NSError *err = nil;
  [self.engine startAndReturnError:&err];
  if (err) {
    NSLog(@"%@", err);
    [NSException raise:NSInternalInconsistencyException format:@"%@", err.description, nil];
    return;
  }
  
  [self.playerNode play];
  
  self.bufferQueue = [NSMutableArray array];
  self.processedBuffers = [NSMutableArray array];
  
  self.endCondition = [[NSCondition alloc] init];
  [self.endCondition lock];
  
  self.decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(decoderThreadMain) object:nil];
  [self.decoderThread start];
}

- (void)updateVolume
{
  self.mixerNode.outputVolume = self.volume * self.volCoef;
}

- (void)decoderThreadMain
{
  const char *filename = [self.oggPath cStringUsingEncoding:NSASCIIStringEncoding];
  _file = fopen(filename, "rb");
  
  [self openDecoder];
  
  struct timespec tim, tim2;
  tim.tv_sec = 0;
  
  while (![NSThread currentThread].isCancelled) {
    if (self.isPlaying) {
      while (self.queueCount < kOggBufferCount) {
        [self enqueueNextBuffer:NULL];
      }
    }
    
    tim.tv_nsec = 10000000L;
    nanosleep(&tim, &tim2);
  }
  
  [self closeDecoder];
  fclose(_file);
  [self.endCondition signal];
}

- (long)enqueueNextBuffer:(size_t *)sz
{
  if (self.eof) {
    [self rewind];
    self.eof = NO;
  }
  
  Float32 data[2][kOggChanBufferSize];
  int framesRead = 0;
  long result = 0;
  
  while (framesRead < kOggChanBufferSize) {
    float **pcm;
    result = ov_read_float(&_stream, &pcm, kOggChanBufferSize - framesRead, 0);
    
    if (result > 0) {
      memcpy(data[0] + framesRead, pcm[0], result * sizeof(Float32));
      memcpy(data[1] + framesRead, pcm[1], result * sizeof(Float32));
      framesRead += result;
    } else {
      if (result < 0) {
        NSLog(@"%@", [self oggErrorString:result]);
        if (sz) *sz = 0;
        return 0;
      } else {
        self.eof = YES;
        break;
      }
    }
  }
  
  if (sz) *sz = framesRead * sizeof(Float32);
  if (framesRead == 0) {
    return 0;
  }
  
  AVAudioPCMBuffer *buffer = nil;
  if (!buffer) {
    AVAudioChannelLayout *chLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_Stereo];
    AVAudioFormat *chFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                               sampleRate:44100.0
                                                              interleaved:NO
                                                            channelLayout:chLayout];
    buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:chFormat
                                           frameCapacity:kOggBufferSize];
  }
  
  ((AudioBuffer *)&buffer.audioBufferList->mBuffers[0])->mDataByteSize = sizeof(Float32);
  ((AudioBuffer *)&buffer.audioBufferList->mBuffers[1])->mDataByteSize = sizeof(Float32);
  
  for (int i = 0; i < framesRead; i++) {
    Float32 l = data[0][i];
    Float32 r = data[1][i];
    ((Float32 *)buffer.audioBufferList->mBuffers[0].mData)[i] = l;
    ((Float32 *)buffer.audioBufferList->mBuffers[1].mData)[i] = r;
  }
  buffer.frameLength = framesRead;
  self.queueCount++;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.playerNode scheduleBuffer:buffer atTime:nil options:0 completionHandler:^{
      self.queueCount--;
    }];
  });
  
  return result;
}

- (void)openDecoder
{
  int result = ov_open(_file, &_stream, NULL, 0);
  if (result < 0) {
    NSLog(@"Couldn't open OGG stream: %@", [self oggErrorString:result]);
    return;
  }
  
  _vorbisInfo = ov_info(&_stream, -1);
  _vorbisComment = ov_comment(&_stream, -1);
}

- (void)closeDecoder
{
  ov_clear(&_stream);
  memset(&_stream, 0, sizeof(OggVorbis_File));
  
  _vorbisInfo = NULL;
  _vorbisComment = NULL;
}

- (void)rewind
{
  ov_raw_seek(&_stream, 0);
}

- (NSString *)oggErrorString:(long)code
{
  switch(code) {
    case OV_EREAD:
      return @"Read from media.";
    case OV_ENOTVORBIS:
      return @"Not Vorbis data.";
    case OV_EVERSION:
      return @"Vorbis version mismatch.";
    case OV_EBADHEADER:
      return @"Invalid Vorbis header.";
    case OV_EFAULT:
      return @"Internal logic fault (bug or heap/stack corruption)";
    default:
      return @"Unknown OGG error.";
  }
}

@end
