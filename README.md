# SQF_plusplus_Transpiler
A transpiler to transform a new procedural language, SQF++, to the Arma 3 scripting language SQF.


Sample SQF++ Snippet

```
// privatization built in with variable definitions
var _x;
var _y = 5 + 2;

// stylistic changes
if (_y > 5) {
  _x = (_y * 5) + 2
} else {
  _x = 31 - 22.5;
}

// built in object support
// using the sOOP library
_object = new("classname");
_object.property1 = _object.method1("arg1","arg2");

// SQF commands as functions in classic format
setDamage(player(), damage(player()) * 0.50);

// classic for loop
// ++ and += styled number manipulation operators
for(var _z = _y; _z < 50; _z++) {
  _z += 5;
}
```
