//
//  BGMManager.h
//  BGMKit
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import <Foundation/Foundation.h>

@class BGMTrackDefinition;

/// The central BGM singleton object.
@interface BGMManager : NSObject

/// The definition of the currently playing track.
@property (nonatomic, readonly) BGMTrackDefinition *currentTrack;

/// Readonly; whether music is currently playing.
@property (nonatomic, readonly) BOOL isPlaying;

/// Whether to mute the currently playing music.
@property (atomic, assign) BOOL mute;

/// Whether to duck the currently playing music to the `duckingLevel`.
@property (atomic, assign) BOOL duck;

/// The level to duck music to. Defaults to 0.3.
@property (nonatomic, assign) double duckingLevel;

/// The master output volume. Defaults to 1.0.
@property (atomic, assign) double masterVolume;

/// Whether the player should fade in when new tracks start. Defaults to NO.
@property (nonatomic, assign) BOOL fadeInNewTracks;

/// The singleton BGMManager object.
+ (instancetype)sharedInstance;

/// Play a BGM track defined by the provided track definition.
- (void)play:(BGMTrackDefinition *)toPlay completion:(void (^)())completion;

/// Stop the current music.
- (void)stopWithCompletion:(void (^)())completion;

@end
