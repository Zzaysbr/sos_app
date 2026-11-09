#!/usr/bin/env python3
"""Compile the production thumbnail MIME helper; optionally extract a private poster.

Reports dimensions only. Does not copy attachment bytes or print private paths.
This macOS check is not physical iPhone/iPad acceptance.
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--file', type=Path)
args = parser.parse_args()
source = Path('packages/compress_video/darwin/compress_video/Sources/compress_video/Thumbnails.swift').read_text()
helper = source.split('// BEGIN SOS OPAQUE THUMBNAIL MIME', 1)[1].split('// END SOS OPAQUE THUMBNAIL MIME', 1)[0]
assert 'options: cvThumbnailAssetOptions(url: url, header: header)' in source
swift = '''import Foundation
import AVFoundation
HELPER
let header = Data([0,0,0,32] + Array("ftypisom".utf8))
let opaque = URL(fileURLWithPath: "/opaque/content")
precondition(cvThumbnailAssetOptions(url:opaque,header:header)?[AVURLAssetOverrideMIMETypeKey] as? String == "video/mp4")
precondition(cvThumbnailAssetOptions(url:opaque,header:Data([0,0,0,32] + Array("ftypqt  ".utf8)))?[AVURLAssetOverrideMIMETypeKey] as? String == "video/quicktime")
precondition(cvThumbnailAssetOptions(url:opaque,header:Data()) == nil)
precondition(cvThumbnailAssetOptions(url:opaque,header:Data(repeating:0,count:12)) == nil)
precondition(cvThumbnailAssetOptions(url:URL(string:"https://example.invalid/content")!,header:header) == nil)
precondition(cvThumbnailAssetOptions(url:URL(fileURLWithPath:"/opaque/clip.mp4"),header:header) == nil)
if CommandLine.arguments.count > 1 {
  let file = URL(fileURLWithPath:CommandLine.arguments[1])
  let handle = try FileHandle(forReadingFrom:file)
  let head = try handle.read(upToCount:12) ?? Data()
  try handle.close()
  let asset = AVURLAsset(url:file,options:cvThumbnailAssetOptions(url:file,header:head))
  let generator = AVAssetImageGenerator(asset:asset)
  generator.appliesPreferredTrackTransform = true
  generator.maximumSize = CGSize(width:320,height:320)
  let image = try generator.copyCGImage(at:CMTime(value:200,timescale:1000),actualTime:nil)
  precondition(image.width > 0 && image.height > 0 && max(image.width,image.height) <= 320)
  print("{\\"poster_extraction\\":\\"PASS\\",\\"width\\":\\(image.width),\\"height\\":\\(image.height)}")
}
print("thumbnail MIME helper checks PASS")
'''.replace('HELPER', helper)
with tempfile.TemporaryDirectory(prefix='sos-thumb-check-') as directory:
    file = Path(directory) / 'main.swift'
    binary = Path(directory) / 'check'
    file.write_text(swift)
    subprocess.run(['swiftc', '-suppress-warnings', str(file), '-o', str(binary)], check=True)
    subprocess.run([str(binary)] + ([str(args.file)] if args.file else []), check=True)
