//
//  BGMTrackDefinition.h
//  Pods
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BGMTrackFormat) {
  BGMTrackFormatUnknown = 0,
  BGMTrackFormatOGGVorbis
};

/// Encapsulates a looping or one-shot BGM track.
@interface BGMTrackDefinition : NSObject

/// The format of the track. Currently fixed to BGMTrackFormatOGGVorbis.
/// This will perhaps change in later versions of BGMKit.
@property (nonatomic, readonly) BGMTrackFormat trackFormat;

/// The base volume of the music track. Defaults to 1.0.
@property (nonatomic, assign) double baseVolume;

/// Whether the BGM should loop. Defaults to YES.
@property (nonatomic, assign) BOOL shouldLoop;

/// The name of the bundle resource for the track intro, without file extension.
@property (nonatomic, strong) NSString *introName;

/// The name of the bundle resource for the track intro, without file extension.
@property (nonatomic, strong) NSString *loopName;

/// Create a BGMTrackDefinition with an intro and a loop body.
- (id)initWithIntroName:(NSString *)intro loopName:(NSString *)loop;

/// Create a BGMTrackDefinition with a loop body.
- (id)initWithLoopName:(NSString *)loop;

@end
