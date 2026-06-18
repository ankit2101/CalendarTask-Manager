# Prebuilt llama.cpp xcframework for on-device task extraction.
#
# CocoaPods downloads and links this automatically during `flutter build macos`
# (referenced from macos/Podfile), so the on-device LLM works with no manual
# setup — the framework ends up bundled inside the .app just like whisper.
#
# To upgrade llama.cpp: pick a tag from https://github.com/ggml-org/llama.cpp/releases
# that ships a `llama-<tag>-xcframework.zip` asset, bump `version` and the URL
# below, then re-check macos/Runner/LlamaBridge.swift against that tag's llama.h.
Pod::Spec.new do |s|
  s.name             = 'llama'
  # CocoaPods requires a semver-style version; this encodes llama.cpp build b9692.
  # The actual release tag lives in s.source below.
  s.version          = '0.0.9692'
  s.summary          = 'Bundled llama.cpp for on-device task extraction.'
  s.description      = 'Prebuilt llama.cpp xcframework, auto-downloaded by CocoaPods so on-device task extraction works with no manual setup.'
  s.homepage         = 'https://github.com/ggml-org/llama.cpp'
  s.license          = { :type => 'MIT', :text => 'llama.cpp is MIT licensed. See https://github.com/ggml-org/llama.cpp/blob/master/LICENSE' }
  s.author           = { 'ggml-org' => 'https://github.com/ggml-org/llama.cpp' }
  s.platform         = :osx, '10.15'
  s.source           = { :http => 'https://github.com/ggml-org/llama.cpp/releases/download/b9692/llama-b9692-xcframework.zip' }
  s.vendored_frameworks = 'build-apple/llama.xcframework'
end
