Pod::Spec.new do |s|
  s.name             = 'flutter_nearby_connections_plus'
  s.version          = '0.0.1'
  s.summary          = 'Flutter nearby connections plugin'
  s.description      = 'Flutter plugin for peer-to-peer connectivity and discovery of nearby devices.'

  s.homepage         = 'https://github.com/edgarladeira/flutter_nearby_connections_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_nearby_connections_plus' => 'maintained fork' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '15.0'
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  s.dependency 'SwiftyJSON', '~> 4.0'

  s.module_name      = 'flutter_nearby_connections_plus'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end