{ stdenv, lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "civo";
  version = "1.0.40";

  src = fetchFromGitHub {
    owner  = "civo";
    repo   = "cli";
    rev    = "v${version}";
    sha256 = "sha256-rsO7vGPr80/ChoNtRGuJDnVDzxwBgLD//iMZEfvxvHc=";
  };

  vendorSha256 = "sha256-gBVSpjoAfbxlJnlrFrsBupJgVQ59sh1ipOry0Mgppig=";

  CGO_ENABLED = 0;

  # Some lint checks fail
  doCheck = false;

  ldflags = [
    "-s"
    "-X github.com/civo/cli/cmd.VersionCli=${version}"
    "-X github.com/civo/cli/cmd.CommitCli=${src.rev}"
    "-X github.com/civo/cli/cmd.DateCli=unknown"
  ];

  doInstallCheck = false;

  postInstall = ''
    mv $out/bin/cli $out/bin/civo
  '';

  meta = with lib; {
    description = "CLI for interacting with Civo resources";
    homepage = "https://github.com/civo/cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ berryp ];
  };
}
