//
//  BGMManager.m
//  BGMKit
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import "BGMManager.h"

@interface BGMManager ()

@property (nonatomic, readwrite) BGMTrackDefinition *currentTrack;
@property (nonatomic, readwrite) BOOL isPlaying;

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

- (void)play:(BGMTrackDefinition *)toPlay
{
  self.currentTrack = toPlay;
  self.isPlaying = YES;
  // TODO
}

- (void)stop
{
  self.currentTrack = nil;
  self.isPlaying = NO;
  // TODO
}

@end
