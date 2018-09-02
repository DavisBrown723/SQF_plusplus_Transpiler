#define CLASSNAME_PROPERTY      "sqfpp__CLASSNAME"
#define PARENTS_PROPERTY        "sqfpp__PARENTS"
#define DESTRUCTORS_PROPERTY    "sqfpp__DESTRUCTORS"
#define VARIABLES_PROPERTY      "sqfpp__VARIABLES"
#define METHODS_PROPERTY        "sqfpp__METHODS"
#define IS_CLASS_PROPERTY       "sqfpp__isClass"

#define IS_CLASS(var)           (if (var isequaltype locationnull && {var getvariable [IS_CLASS_PROPERTY, false]}) then {true} else {false})

// globals

soop_allClasses = [];

soop_fnc_getClassTemplate = {
    missionnamespace getvariable (_this call soop_fnc_stringToFullClassname);
};

// createSimpleObject ["Static", [0, 0, 0]]
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

// set preliminary class data
// so we can read inherited data
// at compile-time
soop_fnc_handleClassPrecompile = {
    params ["_classname","_parents","_varList","_methodList"];

    // compile class data

    private _templateClass = call soop_fnc_createBlankObject;
    _templateClass setvariable [CLASSNAME_PROPERTY, _classname];
    _templateClass setvariable [PARENTS_PROPERTY, _parents];
    _templateClass setvariable [DESTRUCTORS_PROPERTY, []];
    _templateClass setvariable [VARIABLES_PROPERTY, _varList];
    _templateClass setvariable [METHODS_PROPERTY, _methodList];

    soop_allClasses pushback _classname;
    missionnamespace setvariable [(_classname call soop_fnc_stringToFullClassname), _templateClass];

    _classname call soop_fnc_precompile;
};

soop_fnc_precompile = {
    private _classname = _this;

    private _template = _classname call soop_fnc_getClassTemplate;
    private _templateVariableList = _template getVariable VARIABLES_PROPERTY;
    private _templateMethodList = _template getVariable METHODS_PROPERTY;

    private _parentList = (_template getvariable PARENTS_PROPERTY) apply {_x call soop_fnc_getClassTemplate};
    _parentList pushback (_template call soop_fnc_copyObject);

    private _completeParentList = [];
    private _methodsToSkip = ["constructor","copy_constructor","destructor"];

    {
        private _parent = _x;
        private _parentClassname = _parent getvariable CLASSNAME_PROPERTY;

        // handle variable inheritance
        { _templateVariableList pushbackunique _x } foreach (_parent getvariable VARIABLES_PROPERTY);

        // handle method inheritance
        { _templateMethodList pushBackUnique _x } foreach ((_parent getvariable METHODS_PROPERTY) - _methodsToSkip);

        _completeParentList append (_parent getvariable PARENTS_PROPERTY);
    } foreach _parentList;

    _template setvariable [PARENTS_PROPERTY, _completeParentList];

    // recompile any dependant classes
    {
        private _existingClass = _x;
        private _existingTemplate = _existingClass call soop_fnc_getClassTemplate;
        private _existingClassParents = _existingTemplate getVariable PARENTS_PROPERTY;

        if (_classname in _existingClassParents) then {
            _existingClass call soop_fnc_precompile;
        };
    } foreach soop_allClasses;
};

soop_fnc_defineClass = {
    params ["_classname","_parents","_vars","_funcs"];

    private _templateClass = call soop_fnc_createBlankObject;

    _templateClass setvariable [CLASSNAME_PROPERTY, _classname];
    _templateClass setvariable [PARENTS_PROPERTY, _parents];

    private _destructors = _funcs select {(_x select 0) == "destructor"};
    _destructors = _destructors apply {_x select 1};

    _templateClass setvariable [DESTRUCTORS_PROPERTY, _destructors];

    { _templateClass setvariable [_x select 0, _x select 1] } foreach _vars;
    { _templateClass setvariable [_x select 0, _x select 1] } foreach _funcs;

    _templateClass setvariable [VARIABLES_PROPERTY, _vars apply {_x select 0}];
    _templateClass setvariable [METHODS_PROPERTY, (_funcs apply {_x select 0}) - ["constructor","destructor"]];

    missionnamespace setvariable [(_classname call soop_fnc_stringToFullClassname), _templateClass];

    _classname call soop_fnc_compileClass;
};

// By this point we can count on the following conditions to be true
// Each parent class has been compiled
//  - It contains an ordered list of it's parent chain
//  - It contains an ordered list of it's destructor chain
soop_fnc_compileClass = {
    private _classname = _this;

    private _template = _classname call soop_fnc_getClassTemplate;

    private _destructorChain = _template getvariable DESTRUCTORS_PROPERTY;
    private _completeDestructorChain = [];

    private _parentList = (_template getvariable PARENTS_PROPERTY) apply {_x call soop_fnc_getClassTemplate};
    _parentList pushback (_template call soop_fnc_copyObject);

    private _methodsToSkip = ["constructor","copy_constructor","destructor"];

    {
        private _parent = _x;

        private _parentClassname = _parent getvariable CLASSNAME_PROPERTY;

        // handle variable inheritance
        { _template setvariable [_x, _parent getvariable _x] } foreach (_parent getvariable VARIABLES_PROPERTY);

        // handle method inheritance
        { _template setvariable [_x,_parent getvariable _x] } foreach ((_parent getvariable METHODS_PROPERTY) - _methodsToSkip);

        // keep complete list of destructors
        // to call upon destruction
        _completeDestructorChain append (_parent getvariable DESTRUCTORS_PROPERTY);
    } foreach _parentList;

    // destructors should be executed in reverse
    reverse _completeDestructorChain;

    _template setvariable [DESTRUCTORS_PROPERTY, _completeDestructorChain];

    // if any classes that inherit this class
    // have already been defined, recompile them
    {
        private _existingClass = _x;
        private _existingTemplate = _existingClass call soop_fnc_getClassTemplate;
        private _existingClassParents = _existingTemplate getVariable PARENTS_PROPERTY;

        if (_classname in _existingClassParents) then {
            _existingClass call soop_fnc_compileClass;
        };
    } foreach soop_allClasses;
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

soop_fnc_copyVariable = {
    if (IS_CLASS(_this)) then {
        [_this] call soop_fnc_copyInstance
    } else {
        +_this
    };
};

soop_fnc_copyInstance = {
    params ["_instance"];

    private _newInstance = _instance call soop_fnc_copyObject;
    [_newInstance,_instance] call (_newInstance getvariable "copy_constructor");

    _newInstance
};

soop_fnc_initParentClass = {
    params ["_instance","_parentClass","_parameters"];

    private _parentClassTemplate = _parentClass call soop_fnc_getClassTemplate;
    private _parentConstructor = _parentClassTemplate getvariable "constructor";

    ([_instance] + _parameters) call _parentConstructor;
};