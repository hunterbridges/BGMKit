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

@end
