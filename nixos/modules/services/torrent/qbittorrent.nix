{
  config,
  pkgs,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.qbittorrent;
  inherit (builtins) concatStringsSep isAttrs;
  inherit (lib)
    literalExpression
    getExe
    mkEnableOption
    mkOption
    mkPackageOption
    mkIf
    maintainers
    mapAttrsToList
    escape
    ;
  inherit (lib.types)
    str
    port
    path
    nullOr
    unspecified
    ;
  inherit (lib.generators) toINI mkKeyValueDefault mkValueStringDefault;
  gendeepINI = toINI {
    mkKeyValue =
      let
        sep = "=";
      in
      k: v:
      if isAttrs v then
        concatStringsSep "\n" (
          mapAttrsToList (k2: v2: "${escape [ sep ] "${k}\\${k2}"}${sep}${mkValueStringDefault { } v2}") v
        )
      else
        mkKeyValueDefault { } sep k v;
  };
in
{
  options.services.qbittorrent = {
    enable = mkEnableOption "qbittorrent, BitTorrent client.";

    package = mkPackageOption pkgs "qbittorrent-nox" { };

    user = mkOption {
      type = str;
      default = "qbittorrent";
      description = "User account under which qbittorrent runs.";
    };

    group = mkOption {
      type = str;
      default = "qbittorrent";
      description = "Group under which qbittorrent runs.";
    };

    profileDir = mkOption {
      type = path;
      default = "/var/lib/qBittorrent/";
      description = "the path passed to qbittorrent via --profile.";
    };

    openFirewall = mkOption {
      default = false;
      description = "Opens both the webuiPort and torrentPort options ports as tcp in the firewall";
    };

    webuiPort = mkOption {
      default = 8080;
      type = port;
      description = "the port passed to qbittorrent via `--webui-port`";
    };

    torrentingPort = mkOption {
      type = nullOr port;
      description = "the port passed to qbittorrent via `--torrenting-port`";
    };

    serverConfig = mkOption {
      type = unspecified;
      description = ''
        Free-form settings mapped to the `qBittorrent.conf` file in the profile.
        Refer to <https://github.com/qbittorrent/qBittorrent/wiki/Explanation-of-Options-in-qBittorrent>
        you will probably want to run qBittorrent locally once to use the webui to generate the password before setting anything here.
      '';
      example = literalExpression ''
        {
          LegalNotice.Accepted = true;
          Preferences = {
            WebUI = {
              Username = "user";
              Password_PBKDF2 = "generated ByteArray.";
            };
            General.Locale = "en";
          };
        }
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    systemd = {
      tmpfiles.settings = {
        qbittorrent = {
          "${cfg.profileDir}/qBittorrent/"."d" = {
            mode = "700";
            inherit (cfg) user group;
          };
          "${cfg.profileDir}/qBittorrent/config/"."d" = {
            mode = "700";
            inherit (cfg) user group;
          };
          "${cfg.profileDir}/qBittorrent/config/qBittorrent.conf"."L+" = {
            mode = "1500";
            inherit (cfg) user group;
            argument = "${pkgs.writeText "qBittorrent.conf" (gendeepINI cfg.serverConfig)}";
          };
        };
      };
      services.qbittorrent = {
        description = "qbittorrent BitTorrent client";
        wants = [ "network-online.target" ];
        after = [
          "local-fs.target"
          "network-online.target"
          "nss-lookup.target"
        ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = utils.escapeSystemdExecArgs ([
              (getExe cfg.package)
              "--profile=${cfg.profileDir}"
              "--webui-port=${toString cfg.webuiPort}"
            ]
            ++ lib.optional (cfg.torrentingPort != null) "--torrenting-port=${toString cfg.torrentingPort}");
          TimeoutStopSec = 1800;

          # https://github.com/qbittorrent/qBittorrent/pull/6806#discussion_r121478661
          PrivateTmp = false;

          PrivateNetwork = false;
          RemoveIPC = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateUsers = true;
          ProtectHome = "yes";
          ProtectProc = "invisible";
          ProcSubset = "pid";
          ProtectSystem = "full";
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
          CapabilityBoundingSet = "";
          SystemCallFilter = [ "@system-service" ];
        };
      };
    };

    users = {
      users = mkIf (cfg.user == "qbittorrent") {
        qbittorrent = {
          inherit (cfg) group;
          isSystemUser = true;
        };
      };
      groups = mkIf (cfg.group == "qbittorrent") { qbittorrent = { }; };
    };
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall ([
      cfg.webuiPort
    ] ++ lib.optional (cfg.torrentingPort != null) cfg.torrentingPort);
  };
  meta.maintainers = with maintainers; [ nu-nu-ko ];
}
