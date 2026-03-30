class ScrollcodeRelay < Formula
    desc "Local macOS relay for iOS and Codex App Server RPC"
    homepage "https://github.com/ScollCode/homebrew-scrollcode"
    version "0.1.0"

    on_macos do
      on_arm do
        url "https://github.com/ScollCode/homebrew-scrollcode/releases/download/v0.1.0/ScrollCode_0.1.0_darwin_arm64.tar.gz"
        sha256 "ARM64_SHA256"
      end

      on_intel do
        url "https://github.com/ScollCode/homebrew-scrollcode/releases/download/v0.1.0/ScrollCode_0.1.0_darwin_amd64.tar.gz"
        sha256 "AMD64_SHA256"
      end
    end

    def install
      bin.install "ScrollCode" => "ScrollCode"
    end

    def caveats
      <<~EOS
        The executable is installed as:
          ScrollCode

        Default runtime expects the `codex` CLI to be available on PATH.
      EOS
    end

    test do
      assert_predicate bin/"ScrollCode", :exist?
    end
  end
