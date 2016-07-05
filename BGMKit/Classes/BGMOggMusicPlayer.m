//
//  BGMKitOggMusicPlayer.m
//  BGMKit
//
//  Created by Hunter Bridges on 3/3/16.
//

#import "BGMOggMusicPlayer.h"
#import "BGMTrackDefinition.h"

static const size_t kOggBufferCount = 3;
static const size_t kOggBufferFrameCapacity = 1024 * 32;
static const size_t kOggChannels = 2;
static const size_t kOggBufferSize = kOggBufferFrameCapacity * kOggChannels * sizeof(Float32);
static const size_t kOggChanBufferSize = kOggBufferFrameCapacity * sizeof(Float32);

@import AVFoundation;

#include "ogg.h"
#include "codec.h"
#include "vorbisenc.h"
#include "vorbisfile.h"

typedef struct {
  BOOL initialized;
  FILE *file;
  OggVorbis_File stream;
  vorbis_info *vorbisInfo;
  vorbis_comment *vorbisComment;
} OGGVorbisFileBundle;

@interface BGMOggMusicPlayer () {
  OGGVorbisFileBundle _intro;
  OGGVorbisFileBundle _loop;
  
  AudioQueueRef _outputQueue;
  AudioQueueBufferRef _buffers[kOggBufferCount];
}

@property (nonatomic, copy, readwrite) BGMTrackDefinition *trackDefinition;
@property (atomic, assign, readwrite) BOOL isPlaying;

@property (nonatomic, assign) BOOL initialized;

@property (atomic, assign) int queueCount;

@property (nonatomic, strong) NSLock *outputLock;
@property (nonatomic, assign) BOOL eof;

@property (nonatomic, strong) CADisplayLink *fadeLink;
@property (nonatomic, assign) CFTimeInterval fadeStartAt;
@property (nonatomic, assign) float fadeFrom;
@property (nonatomic, assign) float fadeTo;
@property (nonatomic, assign) float fadeDuration;
@property (nonatomic, copy) void (^fadeCompletion)();

@property (nonatomic, readonly) NSString *introPath;
@property (nonatomic, readonly) NSString *loopPath;
@property (nonatomic, readonly) BOOL hasIntro;
@property (nonatomic, assign) BOOL playedIntro;

@end

@implementation BGMOggMusicPlayer

- (id)initWithTrackDefinition:(BGMTrackDefinition *)trackDefinition
{
  self = [super init];
  if (self) {
    self.trackDefinition = trackDefinition;
    self.volume = 1.f;
    self.volCoef = 1.f;
  }
  return self;
}

- (NSString *)pathForOGGNamed:(NSString *)name
{
  if (!name) {
    return nil;
  }
  NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"ogg"];
  if (path == nil) {
    [NSException raise:NSInvalidArgumentException format:@"OGG file not found: %@", self.trackDefinition.introName, nil];
    return nil;
  }
  return path;
}

- (void)dealloc
{
  if (self.isPlaying) {
    [self stop];
  }
}

#pragma mark - Accessors

- (NSString *)introPath
{
  return [self pathForOGGNamed:self.trackDefinition.introName];
}

- (NSString *)loopPath
{
  return [self pathForOGGNamed:self.trackDefinition.loopName];
}

- (BOOL)hasIntro
{
  return !!self.trackDefinition.introName;
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

#pragma mark - Public

- (void)play
{
  if (!self.initialized) {
    [self initialize];
  }
}

- (void)stop
{
  if (!_outputQueue) {
    return;
  }
  
  AudioQueueStop(_outputQueue, false);
  
  self.queueCount = 0;
  
  for (int i=0; i < kOggBufferCount; i++) {
    _buffers[i] = NULL;
  }
  AudioQueueDispose(_outputQueue, false);
  _outputQueue = NULL;
  
  [self closeDecoder:&_intro];
  [self closeDecoder:&_loop];
  
  self.initialized = NO;
  self.isPlaying = NO;
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

#pragma mark - Stream Management

- (void)openDecoder:(OGGVorbisFileBundle *)bundle withPath:(NSString *)path
{
  if (bundle->initialized) {
    return;
  }
  
  const char *filename = [path cStringUsingEncoding:NSASCIIStringEncoding];
  bundle->file = fopen(filename, "rb");
  
  int result = ov_open(bundle->file, &bundle->stream, NULL, 0);
  if (result < 0) {
    NSLog(@"Couldn't open OGG stream: %@", [self oggErrorString:result]);
    return;
  }
  
  bundle->vorbisInfo = ov_info(&bundle->stream, -1);
  bundle->vorbisComment = ov_comment(&bundle->stream, -1);
  bundle->initialized = YES;
}

- (void)closeDecoder:(OGGVorbisFileBundle *)bundle
{
  if (!bundle->initialized) {
    return;
  }
  
  ov_clear(&bundle->stream);
  memset(&bundle->stream, 0, sizeof(OggVorbis_File));
  
  bundle->vorbisInfo = NULL;
  bundle->vorbisComment = NULL;
}

- (void)rewind:(OGGVorbisFileBundle *)bundle
{
  ov_raw_seek(&bundle->stream, 0);
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

- (void)updateVolume
{
  if (!_outputQueue) {
    return;
  }
  
  double finalVolume = self.volume * self.volCoef;
  AudioQueueSetParameter(_outputQueue, kAudioQueueParam_Volume, finalVolume);
}

void OutputBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
  BGMOggMusicPlayer *player = (__bridge BGMOggMusicPlayer*) inUserData;
  [player processOutputBuffer:inBuffer queue:inAQ];
}

- (void)processOutputBuffer:(AudioQueueBufferRef)buffer queue:(AudioQueueRef)queue {
  OSStatus err;
  if (self.isPlaying == YES) {
    [self.outputLock lock];
    size_t sz = 0;
    [self fillBuffer:buffer outSize:&sz];
    err = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    if (err == 560030580) {
      // Queue is not active due to Music being started or other reasons
      self.isPlaying = NO;
      
      // NOTE: This may put music player into a weird state. Investigate.
    } else if (err == noErr) {
      // OK
    } else {
      NSLog(@"AudioQueueEnqueueBuffer() error %d", err);
    }
    [self.outputLock unlock];
  }
}

- (void)initialize
{
  // Create the env
  OSStatus err;
  
  // Set up stream format fields
  AudioStreamBasicDescription streamFormat;
  streamFormat.mSampleRate = 44100;
  streamFormat.mFormatID = kAudioFormatLinearPCM;
  streamFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked;
  streamFormat.mBitsPerChannel = 32;
  streamFormat.mChannelsPerFrame = 2;
  streamFormat.mBytesPerPacket = 4 * streamFormat.mChannelsPerFrame;
  streamFormat.mBytesPerFrame = 4 * streamFormat.mChannelsPerFrame;
  streamFormat.mFramesPerPacket = 1;
  streamFormat.mReserved = 0;
  
  // Start queue
  self.outputLock = [[NSLock alloc] init];
  
  if (self.hasIntro) {
    [self openDecoder:&_intro withPath:self.introPath];
  }
  
  [self openDecoder:&_loop withPath:self.loopPath];
  
  if (self.isPlaying == NO) {
    self.isPlaying = YES;
    AudioQueueRef outputQueue = NULL;
    err = AudioQueueNewOutput (&streamFormat, OutputBufferCallback, (__bridge void *)self, nil, nil, 0, &outputQueue);
    if (err != noErr) NSLog(@"AudioQueueNewOutput() error: %d", err);
    _outputQueue = outputQueue;
    
    [self updateVolume];
  
    // Enqueue buffers
    for (int i=0; i < kOggBufferCount; i++) {
      err = AudioQueueAllocateBufferWithPacketDescriptions(outputQueue, kOggBufferSize, kOggBufferFrameCapacity, &_buffers[i]);
      if (err == noErr) {
        OutputBufferCallback((__bridge void *)self, outputQueue, _buffers[i]);
      } else {
        NSLog(@"AudioQueueAllocateBuffer() error: %d", err);
        return;
      }
    }
    
    // Start playback
    err = AudioQueueStart(outputQueue, nil);
    if (err != noErr) {
      NSLog(@"AudioQueueStart() error: %d", err);
      self.isPlaying= NO;
      return;
    }
  } else {
    NSLog (@"Error: audio is already playing back.");
  }
}

- (OSStatus)fillBuffer:(AudioQueueBufferRef)buffer outSize:(size_t *)sz
{
  OGGVorbisFileBundle *bundle = NULL;
  if (self.hasIntro && !self.playedIntro) {
    bundle = &_intro;
  } else {
    bundle = &_loop;
  }
  
  if (self.eof) {
    if (self.playedIntro) {
      if (self.loop) {
        // Loop
        [self rewind:&_loop];
        self.eof = NO;
      } else {
        // Song is over.
        [self stop];
        return 0;
      }
    } else {
      // Move to loop
      self.playedIntro = YES;
      self.eof = NO;
      bundle = &_loop;
    }
  }
  
  // Read out of OGG decoder
  Float32 data[kOggChannels][kOggBufferFrameCapacity];
  long chanFrames = kOggBufferFrameCapacity;
  int framesRead = 0;
  long result = 0;
  
  while (framesRead < kOggBufferFrameCapacity) {
    float **pcm;
    result = ov_read_float(&bundle->stream, &pcm, kOggBufferFrameCapacity - framesRead, 0);
    
    if (result > 0) {
      for (int i = 0; i < result; i++) {
        float l = pcm[0][i];
        float r = pcm[1][i];
        data[0][framesRead + i] = l;
        data[1][framesRead + i] = r;
      }
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
  
  size_t targetFrameCount = MIN(framesRead, kOggBufferFrameCapacity);
  
  // Write new buffer
  memset(buffer->mAudioData, 0, kOggBufferSize);
  buffer->mPacketDescriptionCount = 0;
  buffer->mAudioDataByteSize = 0;
  for (int i = 0; i < targetFrameCount; i++) {
    Float32 l = data[0][i];
    Float32 r = data[1][i];
    Float32 *outBuf = (Float32 *)buffer->mAudioData;
    
    Float32 interleaved[kOggChannels] = {l, r};
    memcpy(outBuf + i * kOggChannels, interleaved, sizeof(Float32) * kOggChannels);
    
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mStartOffset = sizeof(Float32) * i * kOggChannels;
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mDataByteSize = sizeof(Float32) * kOggChannels;
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mVariableFramesInPacket = 0;
    buffer->mPacketDescriptionCount++;
  }
  buffer->mAudioDataByteSize = sizeof(Float32) * kOggChannels * buffer->mPacketDescriptionCount;
  
  if (framesRead < targetFrameCount) {
    NSLog(@"Exceeded buffer capacity with stream read left over. Uh oh!");
    [NSException raise:NSInternalInconsistencyException format:@"Exceeded buffer capacity with stream read left over. Uh oh!"];
    return -1;
  }
  
  buffer->mPacketDescriptionCount = sz;
  
  return noErr;
}

@end
