//
//  BGMKitOggMusicPlayer.m
//  BGMKit
//
//  Created by Hunter Bridges on 3/3/16.
//

#import "BGMOggMusicPlayer.h"

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

@interface BGMOggMusicPlayer () {
  FILE *_file;
  OggVorbis_File _stream;
  vorbis_info *_vorbisInfo;
  vorbis_comment *_vorbisComment;
  
  AudioQueueRef _outputQueue;
  AudioQueueBufferRef _buffers[kOggBufferCount];
  int _nextBufferToFill;
  int _enqueuedBufferCount;
}

@property (nonatomic, copy, readwrite) NSString *oggName;
@property (nonatomic, copy, readwrite) NSString *oggPath;
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
  
  _enqueuedBufferCount = 0;
  _nextBufferToFill = 0;
  for (int i=0; i < kOggBufferCount; i++) {
    _buffers[i] = NULL;
  }
  AudioQueueDispose(_outputQueue, false);
  _outputQueue = NULL;
  
  [self closeDecoder];
  
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

#pragma mark - Stream Management

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

- (void)updateVolume
{
  if (!_outputQueue) {
    return;
  }
  
  double finalVolume = self.volume * self.volCoef;
  AudioQueueSetParameter(_outputQueue, kAudioQueueParam_Volume, finalVolume);
}

// TODO: Migrate to AudioQueue
void AudioEngineOutputBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
  BGMOggMusicPlayer *player = (__bridge BGMOggMusicPlayer*) inUserData;
  [player processOutputBuffer:inBuffer queue:inAQ];
}

- (void) processOutputBuffer:(AudioQueueBufferRef)buffer queue:(AudioQueueRef)queue {
  OSStatus err;
  if (self.isPlaying == YES) {
    [self.outputLock lock];
    // if (_enqueuedBufferCount < kOggBufferCount) {
    //   [self enqueueNextBuffer:&sz];
    // }
    size_t sz = 0;
    [self fillBuffer:buffer outSize:&sz];
    err = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    if (err == 560030580) { // Queue is not active due to Music being started or other reasons
      self.isPlaying = NO;
    } else if (err == noErr) {
      _enqueuedBufferCount++;
    } else {
      NSLog(@"AudioQueueEnqueueBuffer() error %d", err);
    }
    [self.outputLock unlock];
  } else {
    // err = AudioQueueStop (queue, NO);
    // if (err != noErr) NSLog(@"AudioQueueStop() error: %d", err);
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
  
  [self updateVolume];
  
  // Start queue
  self.outputLock = [[NSLock alloc] init];
  
  const char *filename = [self.oggPath cStringUsingEncoding:NSASCIIStringEncoding];
  _file = fopen(filename, "rb");
  [self openDecoder];
  
  if (self.isPlaying == NO) {
    self.isPlaying = YES;
    AudioQueueRef outputQueue = NULL;
    err = AudioQueueNewOutput (&streamFormat, AudioEngineOutputBufferCallback, (__bridge void *)self, nil, nil, 0, &outputQueue);
    if (err != noErr) NSLog(@"AudioQueueNewOutput() error: %d", err);
    _outputQueue = outputQueue;
    
    // Enqueue buffers
    _enqueuedBufferCount = 0;
    _nextBufferToFill = 0;
    for (int i=0; i < kOggBufferCount; i++) {
      err = AudioQueueAllocateBufferWithPacketDescriptions(outputQueue, kOggBufferSize, kOggBufferFrameCapacity, &_buffers[i]);
      if (err == noErr) {
        AudioEngineOutputBufferCallback((__bridge void *)self, outputQueue, _buffers[i]);
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
  // Is this doing anything?
  int bufferIndex = _nextBufferToFill++;
  if (_nextBufferToFill >= kOggBufferCount) {
    _nextBufferToFill = 0;
  }
  
  // TODO handle more gracefully for intros and 1-shots
  if (self.eof) {
    [self rewind];
    self.eof = NO;
  }
  
  // Read out of OGG decoder
  Float32 data[2][kOggBufferFrameCapacity];
  long chanFrames = kOggBufferFrameCapacity;
  int framesRead = 0;
  long result = 0;
  
  while (framesRead < kOggBufferFrameCapacity) {
    float **pcm;
    result = ov_read_float(&_stream, &pcm, kOggBufferFrameCapacity - framesRead, 0);
    
    if (result > 0) {
      for (int i = 0; i < result; i++) {
        data[0][framesRead + i] = pcm[0][i];
        data[1][framesRead + i] = pcm[1][i];
      }
      // memcpy(data[0] + framesRead, pcm[0], result * sizeof(Float32));
      // memcpy(data[1] + framesRead, pcm[1], result * sizeof(Float32));
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
  
  // Write new buffer
  memset(buffer->mAudioData, 0, kOggBufferSize);
  buffer->mPacketDescriptionCount = 0;
  for (int i = 0; i < framesRead, i < kOggBufferFrameCapacity; i++) {
    Float32 l = data[0][i];
    Float32 r = data[1][i];
    Float32 *outBuf = (Float32 *)buffer->mAudioData;
    outBuf[i * 2] = l;
    outBuf[i * 2 + 1] = r;
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mStartOffset = sizeof(Float32) * i * 2;
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mDataByteSize = sizeof(Float32) * kOggChannels;
    buffer->mPacketDescriptions[buffer->mPacketDescriptionCount].mVariableFramesInPacket = 1;
    buffer->mAudioDataByteSize += sizeof(Float32) * kOggChannels;
    buffer->mPacketDescriptionCount = i + 1;
  }
  
  if (buffer->mPacketDescriptionCount < kOggBufferFrameCapacity) {
    NSLog(@"Exceeded buffer capacity with stream read left over. Uh oh!");
    [NSException raise:NSInternalInconsistencyException format:@"Exceeded buffer capacity with stream read left over. Uh oh!"];
    return -1;
  }
  
  buffer->mPacketDescriptionCount = sz;
  
  return noErr;
}

@end
