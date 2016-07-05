//
//  BGMOggMusicPlayer.h
//  BGMKit
//
//  Created by Hunter Bridges on 3/3/16.
//

#import <Foundation/Foundation.h>

@class BGMTrackDefinition;
@interface BGMOggMusicPlayer : NSObject

@property (nonatomic, strong, readonly) BGMTrackDefinition *trackDefinition;
@property (nonatomic, readonly) BOOL loop;
@property (atomic, readonly) BOOL isPlaying;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float volCoef;

- (id)initWithTrackDefinition:(BGMTrackDefinition *)trackDefinition;

- (void)play;
- (void)stop;
- (void)pause;

- (void)fadeTo:(float)coef withDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;
- (void)fadeInWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;
- (void)fadeOutWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;

@end
