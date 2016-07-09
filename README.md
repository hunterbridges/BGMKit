# BGMKit

So you wanna play music in your app? Well I got some good news bud, BGMKit is
for you.

BGMKit currently includes `libogg v1.3.2` and `libvorbis v1.3.5`

---

## Why BGMKit?

BGMKit's goal is to take advantage of the pros of using OGG Vorbis for
seamlessly looping background music, while eliminating the cons. What are the
pros and cons of using OGG Vorbis? I invite you to take a walk with me.

---

## The Seamless Looping Conundrum

Seamless background music loops are not as simple to execute on iOS
as they may seem. Consider the following:

|            | Small File Size | Easy Production Workflow | Loops In AVAudioPlayer | Can Decode With System Libraries |
|------------|-----------------|--------------------------|------------------------|----------------------------------|
| WAV/AIFF   |                 |             ✔            |            ✔           |                 ✔                |
| MP3        |        ✔        |                          |                        |                 ✔                |
| AAC (.CAF) |        ✔        |                          |                        |                 ✔                |
| OGG        |        ✔        |             ✔            |                        |                                  |

File sizes per minute of 16 bit, 44.1 KHz Stereo:

| Format   | Size per minute    |
|----------|--------------------|
| WAV/AIFF | 10.584 MB          |
| MP3      | 1.44 MB (192 Kbps) |
| AAC      | 1.44 MB (192 Kbps) |
| OGG      | 958 KB (Quality 6) |

Sources:
* [AudioMountain.com](http://www.audiomountain.com/tech/audio-file-size.html)
* Checking file sizes myself.

When picking a file format for your loops, there is no perfect choice. It's
all about tradeoffs. Given the tables above, here are some deeper thoughts about
each choice.

### WAV/AIFF

WAV and AIFF have the most checkboxes, and they are by far the easiest formats
to implement. You can drop a WAV or AIFF into an AVAudioPlayer and loop it
seamlessly. If you plan on having a maximum of 5 - 7 minutes of music in your
app, these uncompressed formats are probably OK. But as you can see in the
file size chart above, the app bundle size can quickly balloon out of control
when you're bundling music at 10MB/minute. The over-the-air download limit
is also 100 MB, so a huge bundle size can hurt user acquisition.

Another thing to note is that if you want intro pre-rolls, you will have to
implement something custom with AudioQueue.

**Pros**: Easy to implement basic loops, requires no third party decoder.

**Cons**: Extremely large file size, becomes just as difficult to implement
          as other formats if more advanced sequences are required.

### MP3

MP3 has a reasonable file size, and can also be decoded by iOS' system
libraries. However, due to the way MP3s are encoded, there are always some number
of empty frames at the beginning and end of the file. MP3s that are to be used
in a seamless loop must be encoded [in a very particular way](http://www.compuphase.com/mp3/mp3loops.htm).
This involves individually modifying each exported MP3 to align to predefined
decoder block sizes of 1152 frames, which can be a very large technical hurdle
depending on your team. Since this workflow involves precise manipulation of the
waveforms, it can be very error prone.

MP3s prepared this way will still not seamlessly loop using AVAudioPlayer.
A lower level implementation using AudioQueue must be used that accounts for
the frame alignment. The [Gapless-MP3-Player](https://github.com/emotionrays/Gapless-MP3-Player) library
supports playback of MP3 files prepared in this way. Kostya Teterin also provided
a [write-up](http://gamua.com/blog/2012/05/gapless-mp3-audio-on-ios/) explaining
how he implemented the library.

**Pros**: Small file sizes, requires no third party decoder.

**Cons**: Incurs a large production workflow cost, requires a low-level
          AudioQueue-based implementation in order to loop seamlessly.

### AAC

AAC is a similar case to MP3. Small file size, can be decoded by iOS' system
libraries. AACs are similar to MP3s in that they require empty frames at the
beginning (priming frames) and end (remainder frames) of the file.
They differ in that AAC's priming and remainder frames are variable, so one
must use the `afinfo` command line tool to extract the number them from your
encoded file. And again, AVAudioPlayer doesn't seamlessly loop AAC files natively.
A separate AudioQueue implementation must be made to account for the frame alignment.
[Apple has a detailed write-up on all of this here](https://developer.apple.com/library/prerelease/content/qa/qa1636/_index.html).

Due to the variable frame alignment, in order to create a flexible gapless AAC
playback system, one would have to maintain the priming and remainder frame count
metadata alongside the actual music assets. This incurs a workflow cost
comparable to the MP3 approach, as well as introduces the possibility that the
frame metadata could become out of sync with the music assets through the
course of development.

**Pros**: Small file sizes, requires no third party decoder.

**Cons**: Incurs a large production workflow cost, requires a low-level
          AudioQueue-based implementation in order to loop seamlessly,
          metadata must be maintained alongside music assets.

### OGG Vorbis

OGG Vorbis has the smallest file size out of all of the file types considered.
This file format also doesn't have any priming or remainder frames before or
after the waveform data. With OGG, you can fit over an hour of music in your
application without going over the over-the-air download limit, and the
production workflow is just as easy as using WAV/AIFF.

The biggest gotcha is that the OGG Vorbis decoder is not included among the iOS
system libraries. An implementation must also include the `libogg` and `libvorbis`
themselves. Don't fret; OGG Vorbis has been under development since 1998,
so the libraries have been battle-hardened over the course of almost two decades.
Most audio software supports exporting in OGG Vorbis format.
[Read more about it here](https://xiph.org/vorbis/).

Because it requires a third party decoder, OGG Vorbis is not compatible with
AVAudioPlayer at all. Implementations using it must be created from scratch.

**Pros**: Small file sizes, painless production workflow

**Cons**: Requires third-party decoder, requires a low-level
          AudioQueue-based implementation.

---

## Installation

BGMKit is in _1337 Beta Test_ mode, so it's not True Pod™ yet. So here's the
deal: ya gotta ref the repo.

```ruby
pod "BGMKit", :git => "https://github.com/hunterbridges/BGMKit.git"
```

---

## How Do

Adding music to your app is really not that big of a deal. Do you know how to
dance? How to do the "2-Step?" Because it's a simple 2 step process:

1. Hire me to write music for your app ([Check me out on Soundcloud](https://soundcloud.com/hunty))
2. Use BGMKit to put the music in your app.

Once you have a precious OGG file, let's say for example `GoodVibes.ogg`, just

```objc
BGMTrackDefinition *goodVibes = [[BGMTrackDefinition alloc] initWithLoopName:@"GoodVibes"];

BGMManager *manager = [BGMManager sharedInstance];
[manager play:goodVibes completion:^{
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

---

## Author

[Hunter Bridges](http//hunterbridges.com/)
[@hunterbridges](https://twitter.com/hunterbridges)

---

## License

BGMKit is available under the MIT license. See the LICENSE file for more info.
