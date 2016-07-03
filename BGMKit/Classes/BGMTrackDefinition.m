//
//  BGMTrackDefinition.m
//  Pods
//
//  Created by Hunter Bridges on 7/2/16.
//
//

#import "BGMTrackDefinition.h"

@implementation BGMTrackDefinition

- (id)init
{
  self = [super init];
  if (self) {
    self.baseVolume = 1.0;
    self.shouldLoop = YES;
  }
  return self;
}

#pragma mark - Accessors

- (BGMTrackFormat)trackFormat {
  return BGMTrackFormatOGGVorbis;
}

- (id)initWithIntroName:(NSString *)intro loopName:(NSString *)loop
{
  self = [self init];
  if (self) {
    self.introName = intro;
    self.loopName = loop;
  }
  return self;
}

- (id)initWithLoopName:(NSString *)loop
{
  return [self initWithIntroName:nil loopName:loop];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
  if ([object isKindOfClass:[BGMTrackDefinition class]]) {
    BGMTrackDefinition *def = (BGMTrackDefinition *)object;
    BOOL loopsMatch = [def.loopName isEqualToString:self.loopName];
    BOOL introsMatch = ((def.introName == nil && self.introName == nil) ||
                        [def.introName isEqualToString:self.introName]);
    return introsMatch && loopsMatch;
  }
  return NO;
}

@end
