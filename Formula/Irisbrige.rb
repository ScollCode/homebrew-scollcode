class Irisbrige < Formula
    desc "Local macOS relay for iOS and Codex App Server RPC"
    homepage "https://github.com/Irisbrige/homebrew-irisbrige"
    version "0.2.0"

    on_macos do
      on_arm do
        url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.3.0/irisbrige-edge_0.3.0_darwin_arm64.tar.gz"
        sha256 "719eb4bced0e835b80d5b0adeab6b445044c52b341c975958fac33ed3ed81354"
      end

      on_intel do
        url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.3.0/irisbrige-edge_0.3.0_darwin_amd64.tar.gz"
        sha256 "d69656c00fddfe738b63ce0c79075da19f06a1980ea8642a18072f6d178c55c6"
      end
    end

    def install
      bin.install "irisbrige-edge" => "irisbrige-edge"
    end

    def caveats
      <<~EOS
        The executable is installed as:
          irisbrige-edge

        Default runtime expects the `codex` CLI to be available on PATH.
      EOS
    end

    test do
      assert_predicate bin/"irisbrige-edge", :exist?
    end
  end
