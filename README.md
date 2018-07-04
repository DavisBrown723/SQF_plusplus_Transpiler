# SQF_plusplus_Transpiler
A transpiler to transform a new procedural language, SQF++, to the Arma 3 scripting language SQF.

Visit the wiki for more in-depth information: https://github.com/DavisBrown723/SQF_plusplus_Transpiler/wiki


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

// single statement loops
if (_y > 5)
	_x = _y * 5 + 2;

while (_y > 100) _y *= 2;

// classic for-loop
// += styled assignment operators
for(var _z = _y; _z < 50; _z += 1) {
  _z += 5;
}

// enumeratored foreach loop
for(var _player : allplayers())
	hint(getpos(_player));

// switch
switch (_x) {
	case 0: {
		break;
	}
	case 1: {
		break;
	}
	default: {
		break;
	}
}

// built in object support
// using the sOOP library
_object = new Classname();
_object.property1 = _object.method1("arg1","arg2");

// SQF commands as functions in classic format
setDamage(player(), damage(player()) * 0.50);

// unnamed scopes
{
    var _a = 22;
}
isnil(_a); // true

// named functions
function add(Number,String _a, Number,String _b) {
	return _a + _b;
}

// lambdas
var _x = function() { var _y = 2 + 5 * 6; };

// lambda invokation
_x();
```
