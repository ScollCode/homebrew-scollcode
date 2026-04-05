class Irisbrige < Formula
  desc "Local macOS relay for iOS and Codex App Server RPC"
  homepage "https://github.com/Irisbrige/homebrew-irisbrige"
  version "0.3.0"

  if Hardware::CPU.arm?
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.3.0/irisbrige-edge_0.3.0_darwin_arm64.tar.gz"
    sha256 "719eb4bced0e835b80d5b0adeab6b445044c52b341c975958fac33ed3ed81354"
  else
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.3.0/irisbrige-edge_0.3.0_darwin_amd64.tar.gz"
    sha256 "d69656c00fddfe738b63ce0c79075da19f06a1980ea8642a18072f6d178c55c6"
  end

  def install
    bin.install "irisbrige-edge"
  end

  service do
    run [opt_bin/"irisbrige-edge", "server"]
    keep_alive true
    process_type :background
    environment_variables PATH: std_service_path_env
    log_path var/"log/irisbrige.log"
    error_log_path var/"log/irisbrige.error.log"
  end

  def caveats
    <<~EOS
      Homebrew formulae cannot auto-start `brew services` during `brew install`.

      The executable is installed as:
        irisbrige-edge

      Start the background service manually with:
        brew services start irisbrige

      The service runs:
        irisbrige-edge server

      Logs are written to:
        #{var}/log/irisbrige.log
        #{var}/log/irisbrige.error.log

      Runtime expects the `codex` CLI to be available on PATH.
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/irisbrige-edge --help")
  end
end
