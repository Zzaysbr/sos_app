#!/usr/bin/env python3
"""Execute production metadata codecs on the JVM and Swift host runtime.

Uses cached Kotlin compiler jars; no dependency download or Bluetooth access.
This checks bytes/parsing/budget, not actual advertising or radio recovery.
"""
import json
import subprocess
import tempfile
from pathlib import Path


def function(source, marker):
    start = source.index(marker)
    body = source.index('{', start)
    depth = 1
    end = body + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def run(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr + result.stdout)
    return result.stdout


android = Path('android/app/src/main/kotlin/com/n1cxltine/sosapp/BleTransportBridge.kt').read_text()
swift = Path('ios/Runner/BleTransport.swift').read_text()
kotlin = '''
object Build { var MODEL = "SM-A536E" }
var discoveryIdentityHint: String? = "0102abff"
ENCODER
DECODER
fun main() {
    val encoded = modelForAdvertising()
    check(encoded.size == 13 && encoded.size + 18 <= 31)
    check(encoded.toList() == listOf(0xa7,0x53,0x4d,0x2d,0x41,0x35,0x33,0x36,0x45,1,2,0xab,0xff).map { it.toByte() })
    check(discoveryMetadata(encoded, null) == ("SM-A536E" to "0102abff"))
    check(discoveryMetadata("SM-A037F".toByteArray(), null) == ("SM-A037F" to null))
    check(discoveryMetadata(null, "R:0102abff:M:I15,5") == ("M:I15,5" to "0102abff"))
    check(discoveryMetadata(null, "M:P14,8") == ("M:P14,8" to null))
    check(discoveryMetadata(encoded.copyOf(12), null) == null)
    check(discoveryMetadata(encoded.copyOf().also { it[0] = 0xa8.toByte() }, null) == null)
    check(discoveryMetadata(encoded.copyOf().also { it[1] = 1 }, null) == null)
    check(discoveryMetadata(null, "R:invalid:M:I15,5") == null)
    discoveryIdentityHint = null
    check(modelForAdvertising().toString(Charsets.US_ASCII) == "SM-A536E")
    println("kotlin-codec-pass")
}
'''.replace('ENCODER', function(android, 'private fun modelForAdvertising()')) \
   .replace('DECODER', function(android, 'private fun discoveryMetadata('))

swift_check = '''import Foundation
enum Codec {
DECODER
}
let encoded = Data([0xa7,0x53,0x4d,0x2d,0x41,0x35,0x33,0x36,0x45,1,2,0xab,0xff])
let parsed = Codec.discoveryMetadata(encoded, name: nil)!
precondition(parsed.model == "SM-A536E" && parsed.hint == "0102abff")
let legacy = Codec.discoveryMetadata(Data("SM-A037F".utf8), name: nil)!
precondition(legacy.model == "SM-A037F" && legacy.hint == nil)
let apple = Codec.discoveryMetadata(nil, name: "R:0102abff:M:I15,5")!
precondition(apple.model == "M:I15,5" && apple.hint == "0102abff")
precondition(Codec.discoveryMetadata(nil, name: "M:P14,8")!.hint == nil)
precondition(Codec.discoveryMetadata(encoded.dropLast(), name: nil) == nil)
var wrongVersion = encoded; wrongVersion[0] = 0xa8
precondition(Codec.discoveryMetadata(wrongVersion, name: nil) == nil)
var malformedModel = encoded; malformedModel[1] = 1
precondition(Codec.discoveryMetadata(malformedModel, name: nil) == nil)
precondition(Codec.discoveryMetadata(nil, name: "R:invalid:M:I15,5") == nil)
precondition("R:0102abff:M:I15,5".utf8.count + 2 <= 31)
print("swift-codec-pass")
'''.replace('DECODER', function(swift, 'private static func discoveryMetadata(')
            .replace('private static func', 'static func', 1))

cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
compiler = sorted((cache / 'org.jetbrains.kotlin/kotlin-compiler-embeddable').glob('2.2.21/*/*.jar'))
if not compiler:
    raise RuntimeError('Cached Kotlin 2.2.21 compiler is required; run Android build first.')
dependencies = [compiler[0]]
for group, artifact in [('org.jetbrains.kotlin', 'kotlin-stdlib'),
                        ('org.jetbrains.kotlin', 'kotlin-reflect'),
                        ('org.jetbrains.kotlin', 'kotlin-script-runtime'),
                        ('org.jetbrains.kotlinx', 'kotlinx-coroutines-core-jvm'),
                        ('org.jetbrains.intellij.deps', 'trove4j'),
                        ('org.jetbrains', 'annotations')]:
    matching = sorted((cache / group / artifact).glob('2.2.21/*/*.jar'))
    jars = matching or sorted((cache / group / artifact).glob('*/*/*.jar'))
    if jars:
        dependencies.append(jars[-1])
classpath = ':'.join(str(p) for p in dependencies)
with tempfile.TemporaryDirectory(prefix='sos-discovery-codec-') as root:
    root = Path(root)
    kotlin_file = root / 'Codec.kt'
    swift_file = root / 'Codec.swift'
    kotlin_file.write_text(kotlin)
    swift_file.write_text(swift_check)
    java_home = run(['/usr/libexec/java_home']).strip()
    java = str(Path(java_home) / 'bin/java')
    run([java, '-cp', classpath, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
         '-no-stdlib', '-no-reflect', '-classpath', classpath,
         '-d', str(root / 'codec.jar'), str(kotlin_file)])
    assert 'kotlin-codec-pass' in run([java, '-cp', str(root / 'codec.jar') + ':' + classpath, 'CodecKt'])
    assert 'swift-codec-pass' in run(['xcrun', 'swift', str(swift_file)])
print(json.dumps({'kotlin_production_codec': 'PASS', 'swift_production_codec': 'PASS',
                  'advertisement_budget': 'PASS', 'scope': 'host codec execution, not radio delivery'}))
