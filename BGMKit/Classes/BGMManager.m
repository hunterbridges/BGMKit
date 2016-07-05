//
//  BGMManager.m
//  BGMKit
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import "BGMManager.h"
#import "BGMTrackDefinition.h"
#import "BGMOggMusicPlayer.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface BGMManager ()

@property (nonatomic, readwrite) BGMTrackDefinition *currentTrack;
@property (nonatomic, strong) BGMOggMusicPlayer *currentPlayer;

@end

@implementation BGMManager

+ (instancetype)sharedInstance
{
  static BGMManager *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[BGMManager alloc] init];
  });
  return shared;
}

- (id)init
{
  self = [super init];
  if (self) {
    self.masterVolume = 1.0;
    self.mute = NO;
    self.duck = NO;
    self.duckingLevel = 0.3;
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
  }
  return self;
}

- (void)play:(BGMTrackDefinition *)toPlay completion:(void (^)())completion
{
  if (toPlay == nil) {
    if (self.currentPlayer) {
      [self.currentPlayer fadeOutWithDuration:1.0 completionBlock:^{
        [self.currentPlayer stop];
        self.currentPlayer = nil;
        self.currentTrack = nil;
        self->_paused = NO;
        if (completion) {
          completion();
        }
      }];
    } else {
      if (completion) {
        dispatch_async(dispatch_get_main_queue(), completion);
      }
    }
    return;
  }
  
  if ([toPlay isEqual:self.currentTrack]) {
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), completion);
    }
    return;
  }
  
  if (self.currentTrack && self.currentPlayer) {
    [self.currentPlayer fadeOutWithDuration:1.0 completionBlock:^{
      [self.currentPlayer stop];
      self.currentPlayer = nil;
      self.currentTrack = nil;
      self->_paused = NO;
      [self play:toPlay completion:completion];
    }];
    return;
  }
  
  BGMOggMusicPlayer *player = [[BGMOggMusicPlayer alloc] initWithTrackDefinition:toPlay];
  self.currentTrack = toPlay;
  self.currentPlayer = player;
  [self updatePlayerVolume];
  if (self.fadeInNewTracks) {
    player.volCoef = 0.0;
    [player fadeTo:(self.duck ? self.duckingLevel : 1.0)
        withDuration:0.5
        completionBlock:nil];
  }
  _paused = NO;
  [player play];
  if (completion) {
    completion();
  }
}

- (void)stopWithCompletion:(void (^)())completion
{
  [self play:nil completion:completion];
}

- (BOOL)isPlaying
{
  return self.currentPlayer.isPlaying;
}

#pragma mark - Accessors

- (void)setMute:(BOOL)mute
{
  _mute = mute;
  [self updatePlayerVolume];
}

- (void)setDuck:(BOOL)duck
{
  BOOL changed = duck != _duck;
  _duck = duck;
  
  if (changed) {
    [self.currentPlayer fadeTo:(duck ? self.duckingLevel : 1.0)
                  withDuration:0.5
               completionBlock:nil];
    
  }
}

- (void)setPaused:(BOOL)paused
{
  if (!self.currentPlayer) {
    return;
  }
  
  _paused = paused;
  if (paused) {
    [self.currentPlayer pause];
  } else {
    [self.currentPlayer play];
  }
}

- (void)setDuckingLevel:(double)duckingLevel
{
  _duckingLevel = duckingLevel;
  // TODO should change actively ducking level if changed while duck == YES
}

- (void)setMasterVolume:(double)masterVolume
{
  _masterVolume = masterVolume;
  [self updatePlayerVolume];
}

#pragma mark - Private

- (void)updatePlayerVolume
{
  if (self.mute) {
    self.currentPlayer.volume = 0.0;
  } else {
    self.currentPlayer.volume = self.masterVolume * self.currentTrack.baseVolume;
  }
}

#pragma mark - Notification Handlers

- (void)handleAppWillResignActive:(NSNotification *)note
{
  self.paused = YES;
}

- (void)handleAppDidBecomeActive:(NSNotification *)note
{
  self.paused = NO;
}

@end
