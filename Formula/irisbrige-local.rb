class IrisbrigeLocal < Formula
  desc "macOS relay for iOS and Codex App Server RPC (local build)"
  homepage "https://github.com/Irisbrige/homebrew-irisbrige"
  version "0.26.0"

  if Hardware::CPU.arm?
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.26.0/irisbrige-local_0.26.0_darwin_arm64.tar.gz"
    sha256 "b51635df44c9254d40c8a08ee3605112baad10d8720ebfbbf74fdc22e55c5854"
  else
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.26.0/irisbrige-local_0.26.0_darwin_amd64.tar.gz"
    sha256 "72f7e92d14ec7d248ce72d4f0ad9eb3cdf91beeda0f92114dbe9382c7be9c64e"
  end





  def install
    bin.install "irisbrige-local"

    (libexec/"irisbrige-local-service").write <<~SH
      #!/bin/sh
      set -e

      SERVICE_BIN="#{opt_bin}/irisbrige-local"
      SERVICE_ENV_DIR="$HOME/.config/irisbrige-local"
      SERVICE_ENV_FILE="$SERVICE_ENV_DIR/service.env"
      SERVICE_PATH="${PATH:-}"

      if [ ! -e "$SERVICE_ENV_FILE" ]; then
        (
          umask 077
          mkdir -p "$SERVICE_ENV_DIR"
          printf '%s\n' \
            '# irisbrige-local background service environment' \
            '# Edit this file directly. Add shell-compatible KEY=VALUE lines below.' \
            '#' \
            '# Examples:' \
            '# MY_PROVIDER_API_KEY=replace-me' \
            '# MY_CUSTOM_BASE_URL=https://example.com' \
            '# IRISBRIGE_ENV_CHECK=service-ready' \
            > "$SERVICE_ENV_FILE"
        ) || true

        if [ -e "$SERVICE_ENV_FILE" ]; then
          echo "irisbrige-local service: created editable env file at $SERVICE_ENV_FILE"
        fi
      fi

      if [ -r "$SERVICE_ENV_FILE" ]; then
        set -a
        . "$SERVICE_ENV_FILE"
        set +a
        echo "irisbrige-local service: loaded environment from $SERVICE_ENV_FILE"
      fi

      if [ -n "$SERVICE_PATH" ]; then
        case ":${PATH:-}:" in
          *":$SERVICE_PATH:"*) ;;
          *)
            if [ -n "${PATH:-}" ]; then
              PATH="${PATH}:$SERVICE_PATH"
            else
              PATH="$SERVICE_PATH"
            fi
            ;;
        esac
      fi

      export PATH
      exec "$SERVICE_BIN" server
    SH
    chmod 0755, libexec/"irisbrige-local-service"
  end

  service do
    run [opt_libexec/"irisbrige-local-service"]
    keep_alive true
    process_type :background
    environment_variables PATH: std_service_path_env
    log_path var/"log/irisbrige-local.log"
    error_log_path var/"log/irisbrige-local.error.log"
  end

  def caveats
    <<~EOS
      Homebrew formulae cannot auto-start `brew services` during `brew install`.

      The executable is installed as:
        irisbrige-local

      Start the background service manually with:
        brew services start irisbrige-local

      `brew services` runs under `launchd` and does not inherit variables from
      your interactive shell.

      The background service uses a dedicated editable env file:
        ~/.config/irisbrige-local/service.env

      If the file does not exist, the service wrapper creates it with commented
      examples on first start.

      Edit that file directly and add shell-compatible `KEY=VALUE` lines, for
      example:
        MY_PROVIDER_API_KEY=replace-me
        MY_CUSTOM_BASE_URL=https://example.com
        IRISBRIGE_ENV_CHECK=service-ready

      Restart after editing:
        brew services restart irisbrige-local

      The service wrapper loads that file before it starts:
        irisbrige-local server

      Logs are written to:
        #{var}/log/irisbrige-local.log
        #{var}/log/irisbrige-local.error.log

      The wrapper preserves Homebrew's PATH so the `codex` CLI stays available.
    EOS
  end

  test do
    assert_path_exists libexec/"irisbrige-local-service"
    assert_match "Usage:", shell_output("#{bin}/irisbrige-local --help")
  end
end
