//
//  BGMViewController.m
//  BGMKit
//
//  Created by Hunter Bridges on 07/02/2016.
//  Copyright (c) 2016 Hunter Bridges. All rights reserved.
//

#import "BGMViewController.h"

@import BGMKit;

@interface BGMViewController ()

@property (strong, nonatomic) IBOutlet UIButton *basicLoopButton;
@property (strong, nonatomic) IBOutlet UIButton *introLoopButton;
@property (strong, nonatomic) IBOutlet UIButton *muteButton;
@property (strong, nonatomic) IBOutlet UIButton *duckButton;
@property (strong, nonatomic) IBOutlet UIButton *pauseButton;

@property (nonatomic, strong) BGMTrackDefinition *basicLoopTrack;
@property (nonatomic, strong) BGMTrackDefinition *introLoopTrack;
@property (strong, nonatomic) IBOutlet UISlider *volumeSlider;

@end

@implementation BGMViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  BGMTrackDefinition *goodVibes = [[BGMTrackDefinition alloc] initWithLoopName:@"GoodVibes"];
  self.basicLoopTrack = goodVibes;
  
  BGMTrackDefinition *finalBoss = [[BGMTrackDefinition alloc] initWithIntroName:@"TakeYouForARide_Intro"
                                                                       loopName:@"TakeYouForARide_Loop"];
  finalBoss.baseVolume = 0.5; // This track is loud af lol
  self.introLoopTrack = finalBoss;
}

#pragma mark - Private

- (void)updateInterface
{
  BGMManager *manager = [BGMManager sharedInstance];
  self.basicLoopButton.selected = manager.currentTrack == self.basicLoopTrack;
  self.introLoopButton.selected = manager.currentTrack == self.introLoopTrack;
  self.muteButton.selected = manager.mute;
  self.duckButton.selected = manager.duck;
  self.pauseButton.selected = manager.paused;
}
#pragma mark - IBActions

- (IBAction)basicLoopPressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  if (manager.isPlaying) {
    if ([manager.currentTrack isEqual:self.basicLoopTrack]) {
      [manager stopWithCompletion:^{
        [self updateInterface];
      }];
    } else {
      [manager play:self.basicLoopTrack completion:^{
        [self updateInterface];
      }];
    }
  } else {
    [manager play:self.basicLoopTrack completion:^{
      [self updateInterface];
    }];
  }
}

- (IBAction)introLoopPressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  if (manager.isPlaying) {
    if ([manager.currentTrack isEqual:self.introLoopTrack]) {
      [manager stopWithCompletion:^{
        [self updateInterface];
      }];
    } else {
      [manager play:self.introLoopTrack completion:^{
        [self updateInterface];
      }];
    }
  } else {
    [manager play:self.introLoopTrack completion:^{
      [self updateInterface];
    }];
  }
}

- (IBAction)mutePressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  manager.mute = !manager.mute;
  [self updateInterface];
}

- (IBAction)duckPressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  manager.duck = !manager.duck;
  [self updateInterface];
}

- (IBAction)pausePressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  manager.paused = !manager.paused;
  [self updateInterface];
}

- (IBAction)volumeSliderChanged:(UISlider *)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  manager.masterVolume = sender.value;
}

@end
