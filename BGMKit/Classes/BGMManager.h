//
//  BGMManager.h
//  BGMKit
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import <Foundation/Foundation.h>

@class BGMTrackDefinition;
@interface BGMManager : NSObject

/// The definition of the currently playing track.
@property (nonatomic, readonly) BGMTrackDefinition *currentTrack;

// Readonly; whether music is currently playing.
@property (nonatomic, readonly) BOOL isPlaying;

/// Whether to mute the currently playing music.
@property (atomic, assign) BOOL mute;

/// Whether to duck the currently playing music to the `duckingLevel`.
@property (atomic, assign) BOOL duck;

/// The level to duck music to. Defaults to 0.3.
@property (nonatomic, assign) BOOL duckingLevel;

@property (atomic, assign) double masterVolume;

/// The singleton BGMManager object.
+ (instancetype)sharedInstance;

/// Play a BGM track defined by the provided track definition.
- (void)play:(BGMTrackDefinition *)toPlay;

/// Stop the current music.
- (void)stop;

@end
