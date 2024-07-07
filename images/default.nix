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


  someStringWithoutInjection = ''
    this has ${toString (1 + 2)}
  '';



  anotherMuliti = ''
  a: [1,2,3,1,2,3,4]


  '';

}