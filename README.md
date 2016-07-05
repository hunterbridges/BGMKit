# BGMKit

So you wanna play music in your app? Ok. Oh what's that you want it to be
OGG Vorbis? Ok. Well I got some good news bud, BGMKit is for you.

## Installation

BGMKit is in _1337 Beta Test_ mode, so it's not True Pod™ yet. So here's the
deal: ya gotta ref the repo.

```ruby
pod "BGMKit", :git => "https://github.com/hunterbridges/BGMKit.git"
```

## How Do

Adding music to your app is really not that big of a deal. Do you know how to
dance? How to do the "2-Step?" Because it's a simple 2 step process:

1. Hire me to write music for your app ([Check me out on Soundcloud](https://soundcloud.com/hunty))
2. Use BGMKit to put the music in your app.

Once you have a precious OGG file, let's say for example `GoodVibes.ogg`, just

```objc
BGMTrackDefinition *goodVibes = [[BGMTrackDefinition alloc] initWithLoopName:@"GoodVibes"];

BGMManager *manager = [BGMManager sharedInstance];
[manager play:self.introLoopTrack completion:^{
    NSLog(@"Thank God it's Friday night and I ju- ju- ju- ju- juuuuust got played");
}];
```

Or if you're Taylor Swift

```swift
let goodVibes = BGMTrackDefinition(loopName: "GoodVibes")

let manager = BGMManager.sharedInstance()
manager.play(goodVibes) {
    print("Thank God it's Friday night and I ju- ju- ju- ju- juuuuust got played")
}
```

So what have you got to lose? Try my pod.

## Author

Hunter Bridges

## License

BGMKit is available under the MIT license. See the LICENSE file for more info.
