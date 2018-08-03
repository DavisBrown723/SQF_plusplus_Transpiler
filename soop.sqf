#define CLASSNAME_PROPERTY      "sqfpp__CLASSNAME"
#define PARENTS_PROPERTY        "sqfpp__PARENTS"
#define DESTRUCTORS_PROPERTY    "sqfpp__DESTRUCTORS"
#define VARIABLES_PROPERTY      "sqfpp__VARIABLES"
#define METHODS_PROPERTY        "sqfpp__METHODS"

soop_fnc_getClassTemplate = {
    missionnamespace getvariable (_this call soop_fnc_stringToFullClassname);
};

soop_fnc_createBlankObject = {
    createlocation ["CBA_NamespaceDummy", [0,0], 0, 0]
};

soop_fnc_stringToFullClassname = {
    "sqfpp_OO_" + _this;
};

soop_fnc_copyObjectProperties = {
    params ["_toPopulate","_toCopy"];

    { _toPopulate setvariable [_x, _toCopy getvariable _x] } foreach (allvariables _toCopy);

    nil
};

soop_fnc_copyObject = {
    private _new = call soop_fnc_createBlankObject;
    [_new,_this] call soop_fnc_copyObjectProperties;

    _new
};

// By this point we can count on the following conditions to be true
// Each parent class has been compiled
//  - It contains an ordered list of it's parent chain
//  - It contains an ordered list of it's destructor chain
soop_fnc_compileClass = {
    private _classname = _this;

    private _template = _classname call soop_fnc_getClassTemplate;

    private _destructorChain = _template getvariable DESTRUCTORS_PROPERTY;
    private _parentList = (_template getvariable PARENTS_PROPERTY) apply {_x call soop_fnc_getClassTemplate};

    private _newParentList = +_parentList;
    _parentList pushback (_template call soop_fnc_copyObject);

    {
        private _parent = _x;

        // handle variable/method inheritance
        { _template setvariable [_x,_parent getvariable _x] } foreach (_parent getvariable VARIABLES_PROPERTY);
        { _template setvariable [_x,_parent getvariable _x] } foreach (_parent getvariable METHODS_PROPERTY);

        if ((_parent getvariable CLASSNAME_PROPERTY) != (_template getvariable CLASSNAME_PROPERTY)) then {
            _newParentList append (_parent getvariable PARENTS_PROPERTY);
            _destructorChain append (_parent getvariable DESTRUCTORS_PROPERTY);
        };
    } foreach _parentList;

    // do we need this
    _parentList deleteat ((count _parentList) - 1);

    _template setvariable [PARENTS_PROPERTY, _newParentList];
};

soop_fnc_defineClass = {
    params ["_classname","_parents","_vars","_funcs"];

    private _templateClass = call soop_fnc_createBlankObject;

    _templateClass setvariable [CLASSNAME_PROPERTY, _classname];
    _templateClass setvariable [PARENTS_PROPERTY, _parents];

    private _destructors = [];
    _destructors append (_funcs select {(_x select 0) == "destructor"});

    _templateClass setvariable [DESTRUCTORS_PROPERTY, _destructors];

    {_templateClass setvariable [_x select 0, _x select 1]} foreach _vars;
    { _templateClass setvariable [_x select 0, _x select 1] } foreach _funcs;

    _templateClass setvariable [VARIABLES_PROPERTY, _vars apply {_x select 0}];
    _templateClass setvariable [METHODS_PROPERTY, (_funcs apply {_x select 0}) - ["constructor","destructor"]];

    missionnamespace setvariable [(_classname call soop_fnc_stringToFullClassname), _templateClass];

    _classname call soop_fnc_compileClass;
};



soop_fnc_newInstance = {
    params ["_classname","_args"];

    private _instance = (_classname call soop_fnc_getClassTemplate) call soop_fnc_copyObject;
    [_instance,_args] call (_instance getvariable "constructor");

    _instance
};

soop_fnc_deleteInstance = {
    {call _x} foreach (_this getvariable DESTRUCTORS_PROPERTY);
    deletelocation __instance;
};