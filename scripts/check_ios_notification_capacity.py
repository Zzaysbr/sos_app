#!/usr/bin/env python3
"""Compile the production notification capacity expression and check both call sites.

This is a native boundary regression check, not a CoreBluetooth hardware test.
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path

source = Path('ios/Runner/BleTransport.swift').read_text()
match = re.search(r'private func peripheralFrameCapacity\(_ central: CBCentral\?\) -> Int \{([^}]+)\}', source)
assert match, 'Missing shared peripheral capacity; query/send must use the same bound'
query = source.split('case "maxFrameBytes":', 1)[1].split('case "dispose":', 1)[0]
flush = source.split('private func flushPeripheral(', 1)[1].split('private func dispose()', 1)[0]
assert 'result(peripheralFrameCapacity(subscribedCentrals[uuid]))' in query
assert 'let maximum = peripheralFrameCapacity(central)' in flush
assert 'guard pending.data.count <= maximum' in flush
swift = '''struct CBCentral { let maximumUpdateValueLength: Int }
func peripheralFrameCapacity(_ central: CBCentral?) -> Int {BODY}
precondition(peripheralFrameCapacity(nil) == 20)
for (native, expected) in [(0,20),(20,20),(185,185),(244,244),(512,512),(514,512)] {
  let limit = peripheralFrameCapacity(CBCentral(maximumUpdateValueLength:native))
  precondition(limit == expected)
  precondition(expected <= limit)
  precondition(!(expected + 1 <= limit))
}
print("capacity boundaries passed")
'''.replace('BODY', match[1])
with tempfile.TemporaryDirectory(prefix='sos-native-capacity-test-') as root:
    path = Path(root) / 'check.swift'
    path.write_text(swift)
    result = subprocess.run(['xcrun', 'swift', str(path)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
print(json.dumps({'native_capacity_boundaries':7,'shared_query_send_guard':'PASS','scope':'Pure production Swift bound + call-site consistency; not hardware delivery'}))
