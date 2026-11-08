#!/usr/bin/env python3
"""Compile production Apple MIME options; optionally probe a private local MP4.

The file path/content is never printed. This is macOS AVFoundation validation,
not proof of iPhone playback or final storage receipt.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--file', type=Path)
args = parser.parse_args()
source = Path('packages/video_player_avfoundation/darwin/video_player_avfoundation/Sources/video_player_avfoundation/VideoPlayerPlugin.swift').read_text()
helper = source.split('// BEGIN SOS LOCAL MEDIA MIME OPTIONS', 1)[1].split('// END SOS LOCAL MEDIA MIME OPTIONS', 1)[0]
assert 'options: fvpLocalMediaAssetOptions(url: url, headers: headers)' in source
swift = '''import Foundation
import AVFoundation
HELPER
let url = URL(fileURLWithPath:"/opaque/content")
let options = fvpLocalMediaAssetOptions(url:url,headers:["Content-Type":"video/mp4"])!
precondition(options[AVURLAssetOverrideMIMETypeKey] as? String == "video/mp4")
let remote = fvpLocalMediaAssetOptions(url:URL(string:"https://example.invalid/content")!,headers:["Content-Type":"video/mp4"])!
precondition(remote[AVURLAssetOverrideMIMETypeKey] == nil)
let unknown = fvpLocalMediaAssetOptions(url:url,headers:["Content-Type":"application/octet-stream"])!
precondition(unknown[AVURLAssetOverrideMIMETypeKey] == nil)
if CommandLine.arguments.count > 1 {
 let file = URL(fileURLWithPath:CommandLine.arguments[1])
 let before = AVURLAsset(url:file)
 let after = AVURLAsset(url:file,options:fvpLocalMediaAssetOptions(url:file,headers:["Content-Type":"video/mp4"]))
 let duration = CMTimeGetSeconds(after.duration)
 precondition(after.tracks.count > 0 && duration > 0)
 var decodedVideo = 0
 var decodedAudio = 0
 for track in after.tracks {
  let reader = try AVAssetReader(asset: after)
  let settings:[String:Any] = track.mediaType == .video
    ? [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
    : [AVFormatIDKey:kAudioFormatLinearPCM]
  let output = AVAssetReaderTrackOutput(track:track, outputSettings:settings)
  reader.add(output)
  precondition(reader.startReading())
  var count = 0
  while output.copyNextSampleBuffer() != nil { count += 1 }
  precondition(reader.status == .completed && count > 0)
  if track.mediaType == .video { decodedVideo += count }
  if track.mediaType == .audio { decodedAudio += count }
 }
 precondition(decodedVideo > 0)
 let report:[String:Any] = ["tracks_before":before.tracks.count,"tracks_after":after.tracks.count,"duration_seconds":duration,"decoded_video_samples":decodedVideo,"decoded_audio_samples":decodedAudio]
 print(String(data:try JSONSerialization.data(withJSONObject:report),encoding:.utf8)!)
}
'''.replace('HELPER', helper)
with tempfile.TemporaryDirectory(prefix='sos-apple-mime-check-') as root:
    path = Path(root) / 'check.swift'
    path.write_text(swift)
    cmd = ['xcrun', 'swift', str(path)]
    if args.file:
        cmd.append(str(args.file))
    result = subprocess.run(cmd, capture_output=True, text=True)
    assert result.returncode == 0, 'Native MIME regression failed; inspect private diagnostics'
    if result.stdout.strip():
        print(result.stdout.strip())
print(json.dumps({'local_mime_option': 'PASS', 'network_not_overridden': 'PASS', 'unknown_mime_not_overridden': 'PASS'}))
