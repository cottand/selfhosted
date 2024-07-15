{ pkgs, ... }: {
  oneLineYaml = "this: { is: [valid, yaml, ${1 + 1}] }";


  someYaml = ''
some-text:
  this: [ is,   an, ]
  unformatted:
    - hello
    - edit this yaml!
    - ugly
    - injection
    - ${toString (1 + 2)}
'';

a = builtins.writeShellScript "my-script.sh" ''
  first_of_array=''${ARRAY[0]}
  from_nix=${lib.escapeShellArg someVar}
  '';


  someStringWithoutInjection = ''
    this has ${toString (1 + 2)}
  '';



  anotherMuliti = ''
a: [1,2,3,1,2,3,4,5,6,8,9,]'';

}