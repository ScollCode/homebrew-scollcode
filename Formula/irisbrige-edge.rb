class IrisbrigeEdge < Formula
  desc "macOS relay for iOS and Codex App Server RPC (edge build)"
  homepage "https://github.com/Irisbrige/homebrew-irisbrige"
  version "0.29.0"

  if Hardware::CPU.arm?
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.29.0/irisbrige-edge_0.29.0_darwin_arm64.tar.gz"
    sha256 "00c8fe4806b35f223b25b9c94143f69a97aeafbc3a9db7b560d8f0fd79b70c7d"
  else
    url "https://github.com/Irisbrige/homebrew-irisbrige/releases/download/v0.29.0/irisbrige-edge_0.29.0_darwin_amd64.tar.gz"
    sha256 "e1cc4a645919289c24759694967a1644ef712ddc3dae55f817ebc24609ac4d46"
  end








  def install
    bin.install "irisbrige-edge"

    (libexec/"irisbrige-edge-service").write <<~SH
      #!/bin/sh
      set -e

      SERVICE_BIN="#{opt_bin}/irisbrige-edge"
      SERVICE_ENV_DIR="$HOME/.config/irisbrige-edge"
      SERVICE_ENV_FILE="$SERVICE_ENV_DIR/service.env"
      SERVICE_PATH="${PATH:-}"

      if [ ! -e "$SERVICE_ENV_FILE" ]; then
        (
          umask 077
          mkdir -p "$SERVICE_ENV_DIR"
          printf '%s\n' \
            '# irisbrige-edge background service environment' \
            '# Edit this file directly. Add shell-compatible KEY=VALUE lines below.' \
            '#' \
            '# Examples:' \
            '# MY_PROVIDER_API_KEY=replace-me' \
            '# MY_CUSTOM_BASE_URL=https://example.com' \
            '# IRISBRIGE_ENV_CHECK=service-ready' \
            > "$SERVICE_ENV_FILE"
        ) || true

        if [ -e "$SERVICE_ENV_FILE" ]; then
          echo "irisbrige-edge service: created editable env file at $SERVICE_ENV_FILE"
        fi
      fi

      if [ -r "$SERVICE_ENV_FILE" ]; then
        set -a
        . "$SERVICE_ENV_FILE"
        set +a
        echo "irisbrige-edge service: loaded environment from $SERVICE_ENV_FILE"
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
    chmod 0755, libexec/"irisbrige-edge-service"
  end

  service do
    # Preserve the legacy launchd label so formula renames do not strand
    # an already-installed background service on user machines.
    name macos: "homebrew.mxcl.irisbrige"
    run [opt_libexec/"irisbrige-edge-service"]
    keep_alive true
    process_type :background
    environment_variables PATH: std_service_path_env
    log_path var/"log/irisbrige.log"
    error_log_path var/"log/irisbrige.error.log"
  end

  def caveats
    <<~EOS
      Homebrew formulae cannot auto-start `brew services` during `brew install`.

      This formula installs the edge executable:
        irisbrige-edge

      Start the background service manually with:
        brew services start irisbrige-edge

      `brew services` runs under `launchd` and does not inherit variables from
      your interactive shell.

      The background service uses a dedicated editable env file:
        ~/.config/irisbrige-edge/service.env

      If the file does not exist, the service wrapper creates it with commented
      examples on first start.

      Edit that file directly and add shell-compatible `KEY=VALUE` lines, for
      example:
        MY_PROVIDER_API_KEY=replace-me
        MY_CUSTOM_BASE_URL=https://example.com
        IRISBRIGE_ENV_CHECK=service-ready

      Restart after editing:
        brew services restart irisbrige-edge

      The service wrapper loads that file before it starts:
        irisbrige-edge server

      The launchd label remains:
        homebrew.mxcl.irisbrige
      to preserve compatibility with existing service installations.

      Logs are written to:
        #{var}/log/irisbrige.log
        #{var}/log/irisbrige.error.log

      The wrapper preserves Homebrew's PATH so the `codex` CLI stays available.
    EOS
  end

  test do
    assert_path_exists libexec/"irisbrige-edge-service"
    assert_match "Usage:", shell_output("#{bin}/irisbrige-edge --help")
  end
end
