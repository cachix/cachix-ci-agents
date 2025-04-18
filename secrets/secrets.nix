let
  admin_domen = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7CTy+OMdA1IfR3EEuL/8c9tWZvfzzDH9cYE1Fq8eFsSfcoFKtb/0tAcUrhYmQMJDV54J7cLvltaoA4MV788uKl+rlqy17rKGji4gC94dvtB9eIH11p/WadgGORnjdiIV1Df29Zmjlm5zqNo2sZUxs0Nya2I4Dpa2tdXkw6piVgMtVrqPCM4W5uorX8CE+ecOUzPOi11lyfCwLcdg0OugXBVrNNSfnJ2/4PrLm7rcG4edbonjWa/FvMAHxN7BBU5+aGFC5okKOi5LqKskRkesxKNcIbsXHJ9TOsiqJKPwP0H2um/7evXiMVjn3/951Yz9Sc8jKoxAbeH/PcCmMOQz+8z7cJXm2LI/WIkiDUyAUdTFJj8CrdWOpZNqQ9WGiYQ6FHVOVfrHaIdyS4EOUG+XXY/dag0EBueO51i8KErrL17zagkeCqtI84yNvZ+L2hCSVM7uDi805Wi9DTr0pdWzh9jKNAcF7DqN16inklWUjtdRZn04gJ8N5hx55g2PAvMYWD21QoIruWUT1I7O9xbarQEfd2cC3yP+63AHlimo9Aqmj/9Qx3sRB7ycieQvNZEedLE9xiPOQycJzzZREVSEN1EK1xzle0Hg6I7U9L5LDD8yXkutvvppFb27dzlr5MTUnIy+reEHavyF9RSNXHTo57myffl8zo2lPjcmFkffLZQ==";
  admin_sander = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO18rhoNZWQZeudtRFBZvJXLkHEshSaEFFt2llG5OeHk";

  admins = [ admin_domen admin_sander ];

  server_aarch64_linux = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN6Wnh5nxINijVxpjSeIPRz7boKaqQ8ocrymvJr/maP";
  server_x86_64_linux = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID1kvbA7lNc1ZL4KFjWkaEk9NxeDAbvOK0d5ElVsB9Vl";
  server_aarch64_darwin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMU/fWaH12GbFob0ZF1Wm/jN0pcgJchQAAW+wzCS+ZzA";

  servers = [ server_aarch64_linux server_x86_64_linux server_aarch64_darwin ];
in {
  "github-runner-token.age".publicKeys = admins ++ servers;

  # extra-access-tokens for Nix. Includes:
  # - github.com basic token. Expires: 15/10/2025
  "nix-access-tokens.age".publicKeys = admins ++ servers;
}
