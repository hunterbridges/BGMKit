//
//  BGMOggMusicPlayer.h
//  BGMKit
//
//  Created by Hunter Bridges on 3/3/16.
//

#import <Foundation/Foundation.h>

@interface BGMOggMusicPlayer : NSObject

@property (nonatomic, copy, readonly) NSString *oggName;
@property (nonatomic, readonly) BOOL loop;
@property (atomic, readonly) BOOL isPlaying;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float volCoef;

- (id)initWithOGGNamed:(NSString *)name;

- (void)play;
- (void)stop;
- (void)pause;

- (void)fadeTo:(float)coef withDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;
- (void)fadeInWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;
- (void)fadeOutWithDuration:(NSTimeInterval)duration completionBlock:(void(^)())completion;

@end
