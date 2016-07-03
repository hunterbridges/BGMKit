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
  
  BGMTrackDefinition *finalBoss = [[BGMTrackDefinition alloc] initWithIntroName:@"FinalBoss_Intro"
                                                                       loopName:@"FinalBoss_Loop"];
  self.introLoopTrack = finalBoss;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Private

- (void)updateInterface
{
  BGMManager *manager = [BGMManager sharedInstance];
  self.basicLoopButton.selected = manager.isPlaying && manager.currentTrack == self.basicLoopTrack;
  self.introLoopButton.selected = manager.isPlaying && manager.currentTrack == self.introLoopTrack;
  self.muteButton.selected = manager.mute;
  self.duckButton.selected = manager.duck;
}
#pragma mark - IBActions

- (IBAction)basicLoopPressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  if (manager.isPlaying) {
    if (manager.currentTrack == self.basicLoopTrack) {
      [manager stop];
    } else {
      [manager play:self.basicLoopTrack];
    }
  } else {
    [manager play:self.basicLoopTrack];
  }
  [self updateInterface];
}

- (IBAction)introLoopPressed:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  if (manager.isPlaying) {
    if (manager.currentTrack == self.introLoopTrack) {
      [manager stop];
    } else {
      [manager play:self.introLoopTrack];
    }
  } else {
    [manager play:self.introLoopTrack];
  }
  [self updateInterface];
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

- (IBAction)volumeSliderChanged:(id)sender {
  BGMManager *manager = [BGMManager sharedInstance];
  manager.masterVolume = [sender doubleValue];
}

@end
