#define VISIT(node) [node,_visitor] call sqfpp_fnc_visitNode

sqfpp_fnc_transform = {
    params ["_tree","_transformations"];

    private _visitor = createlocation ["CBA_NamespaceDummy", [0,0], 0, 0];
    _visitor setvariable ["sqfpp_transformations", _transformations];

    VISIT(_tree);
};

sqfpp_fnc_visitNode = {
    params ["_node","_visitor"];

    // prints call chain for visits
    //private _visited = _visitor getvariable "visited";
    //if (isnil "_visited") then {_visited = []; _visitor setvariable ["visited", _visited]};
    //_visited pushback _node;
    //copytoclipboard str _visited;

    private _nodeType = _node select 0;

    private _transformations = _visitor getvariable "sqfpp_transformations";
    {
        _x params ["_transformationType","_transformationCode"];

        if (_nodeType == _transformationType || _transformationType == "") then {
            [_node,_visitor,"entered"] call _transformationCode;
        };
    } foreach _transformations;

    // if node type was changed from "entered" transformation
    // make sure we don't visit the wrong node
    _nodeType = _node select 0;

    switch (_nodeType) do {
        case "identifier": {

        };
        case "literal": {
            // visit array literal elements?
        };
        case "namespace_accessor": {
            private _left = _node select 1;
            private _right = _node select 2;

            VISIT(_left);
            VISIT(_right);
        };
        case "namespace_block": {
            private _namespace = _node select 1;
            private _blockNodes = _node select 2;

            { VISIT(_x) } foreach _blockNodes;
        };
        case "block": {
            private _statementList = _node select 1;

            { VISIT(_x) } foreach _statementList;
        };
        case "expression_statement": {
            private _statement = _node select 1;

            VISIT(_statement);
        };
        case "variable_definition": {
            private _varIdentifierToken = _node select 1;

            VISIT(_varIdentifierToken);
        };
        case "assignment": {
            private _left = _node select 1;
            private _operator = _node select 2;
            private _right = _node select 3;

            VISIT(_left);
            VISIT(_right);
        };
        case "unary_operation": {
            private _operator = _node select 1;
            private _right = _node select 2;

            VISIT(_right);
        };
        case "unary_statement": {
            private _symbol = _node select 1;
            private _right = _node select 2;

            VISIT(_symbol);
            VISIT(_right);
        };
        case "binary_operation": {
            private _operator = _node select 1;
            private _left = _node select 2;
            private _right = _node select 3;

            VISIT(_left);
            VISIT(_right);
        };
        case "function_call": {
            private _function = _node select 1;
            private _arguments = _node select 2;

            { VISIT(_x) } foreach _arguments;
        };
        case "method_call": {
            private _object = _node select 1;
            private _method = _node select 2;
            private _arguments = _node select 3;

            VISIT(_object);

            if !(_arguments isequalto []) then {
                { VISIT(_x) } foreach _arguments;
            };
        };
        case "class_access": {
            private _object = _node select 1;
            private _member = _node select 2;

            VISIT(_object);
            VISIT(_member);
        };
        case "if": {
            private _condition = _node select 1;
            private _trueBlock = _node select 2;
            private _falseBlock = _node select 3;

            VISIT(_condition);
            if !(_trueBlock isequalto []) then { VISIT(_trueBlock) };
            if !(_falseBlock isequalto []) then { VISIT(_falseBlock) };
        };
        case "while": {
            private _condition = _node select 1;
            private _block = _node select 2;

            VISIT(_condition);
            VISIT(_block);
        };
        case "for": {
            private _pre = _node select 1;
            private _condition = _node select 2;
            private _post = _node select 3;
            private _block = _node select 4;

            VISIT(_pre);
            VISIT(_condition);
            VISIT(_post);
            VISIT(_block);
        };
        case "foreach": {
            private _list = _node select 1;
            private _enumerationVar = _node select 2;
            private _block = _node select 3;

            VISIT(_list);
            VISIT(_enumerationVar);
            VISIT(_block);
        };
        case "switch": {
            private _condition = _node select 1;
            private _cases = _node select 2;

            VISIT(_condition);
            VISIT(_cases);
        };
        case "new_instance": {
            private _class = _node select 1;
            private _arguments = _node select 2;

            //VISIT(_class);
            { VISIT(_x) } foreach _arguments;
        };
        case "delete_instance": {
            private _expression = _node select 1;

            VISIT(_expression);
        };
        case "copy_variable": {
            private _expression = _node select 1;

            VISIT(_expression);
        };
        case "init_parent_class": {
            private _class = _node select 1;
            private _arguments = _node select 2;

            VISIT(_class);
            { VISIT(_x) } foreach _arguments;
        };
        case "lambda": {
            private _parameterList = _node select 1;
            private _body = _node select 2;

            { VISIT(_x) } foreach _parameterList;
            VISIT(_body);
        };
        case "raw_sqf": {
            //private _tokens = _node select 1;
            //
            //[_tokens,_code] call sqfpp_fnc_visitNode;
            //
            //[_type, _tokens]
        };
        case "function_parameter": {
            private _validTypes = _node select 1;
            private _varName = _node select 2;
            private _defaultValue = _node select 3;

            if (_defaultValue isequaltype []) then {
                VISIT(_defaultValue);
            };
        };
        case "named_function": {
            private _identifier = _node select 1;
            private _parameterList = _node select 2;
            private _body = _node select 3;

            { VISIT(_x) } foreach _parameterList;
            VISIT(_body);
        };
        case "class_definition": {
            private _classname = _node select 1;
            private _parents = _node select 2;
            private _varNodes = _node select 3;
            private _funcNodes = _node select 4;

            {
                private _defaultValue = _x select 1;
                VISIT(_defaultValue);
            } foreach _varNodes;

            {
                private _parameters = _x select 1;
                private _body = _x select 2;

                { VISIT(_x) } foreach _parameters;
                VISIT(_body);
            } foreach _funcNodes;
        };
        case "unnamed_scope": {
            private _block = _node select 1;
            private _forceUnscheduled = _node select 2;

            VISIT(_block);
        };
        case "return": {
            private _expression = _node select 1;

            VISIT(_expression);
        };
        case "break": {};
        case "continue": {};
        case "empty_statement": {};
        case "no_statement": {};
        default {
            ["Code Transformer","Node does not support visit operation - %1", [_node]] call sqfpp_fnc_error;
        };
    };

    {
        _x params ["_transformationType","_transformationCode"];

        if (_nodeType == _transformationType || _transformationType == "") then {
            [_node,_visitor,"leaving"] call _transformationCode;
        };
    } foreach _transformations;
};


// common transformations


sqfpp_fnc_precompileClasses = {
    private _tree = _this;

    [_tree,[
        ["class_definition", {
            params ["_node","_visitor","_state"];

            private _inClassDef = _visitor getvariable ["inClassDef", false];

            if (_state == "entered") then {
                _node params ["_type","_classname","_parents","_varNodes","_funcNodes"];

                private _varList = _varNodes apply {_x select 0};
                private _methodList = _funcNodes apply {_x select 0};

                [_classname,_parents,_varList,_methodList] call soop_fnc_handleClassPrecompile;
            };
        }]
    ]] call sqfpp_fnc_transform;
};


sqfpp_fnc_checkTreeValidity = {
    private _tree = _this;

    _tree call sqfpp_fnc_checkParentClassInits;
};

sqfpp_fnc_checkParentClassInits = {
    private _tree = _this;

    [_tree,[
        ["class_definition", {
            params ["_node","_visitor","_state"];

            private _inClassDef = _visitor getvariable ["inClassDef", false];

            switch (_state) do {
                case "entered": {
                    _visitor setvariable ["inClassDef", true];

                    _node params ["_type","_classname","_parents","_varNodes","_funcNodes"];

                    _visitor setVariable ["class", _classname];
                    _visitor setVariable ["classParents", _parents];

                    // manually visit function nodes so
                    // we know when we're inside one
                    {
                        _x params ["_name","_parameters","_body"];

                        VISIT(_body);
                    } foreach _funcNodes;
                };
                case "leaving": {
                    _visitor setvariable ["inClassDef", false];
                };
            };
        }],
        ["init_parent_class", {
            params ["_node","_visitor","_state"];

            private _inClass = _visitor getvariable ["inClassDef", false];

            if (!_inClass) then {
                ["init_super must be used inside of a class method"] call sqfpp_fnc_parseError;
            };

            private _classToInitToken = _node select 1;
            private _classToInit = _classToInitToken select 1;

            private _currentClass = _visitor getVariable "class";
            private _validParents = _visitor getVariable "classParents";

            if !(_classToInit in _validParents) then {
                [format ["init_super class %1 does not inherit from %2", _currentClass, _classToInit]] call sqfpp_fnc_parseError;
            };
        }]
    ]] call sqfpp_fnc_transform;
};

sqfpp_fnc_optimizeTree = {
    private _tree = _this;

    _tree call sqfpp_fnc_removeOneTimeUseVars;
};

sqfpp_fnc_removeOneTimeUseVars = {
    private _tree = _this;

    private _findVarUsageData = {
        params ["_variablesByScope","_varName"];

        scopename "findVarData";

        {
            private _varUsageByBlock = _x;

            {
                if (_varName == (_x select 0)) then {
                    _x breakout "findVarData";
                };
            } foreach _varUsageByBlock;
        } foreach _variablesByScope;
    };

    [_tree,[
        ["block", {
            params ["_node","_visitor","_state"];

            private _inOptimizationPass = _visitor getvariable ["inOptimizationPass",false];

            if (!_inOptimizationPass) then {
                switch (_state) do {
                    case "entered": {
                        // store how many times a variable is used

                        private _variablesByScope = _visitor getvariable "varsByScope";
                        if (isnil "_variablesByScope") then { _variablesByScope = []; _visitor setvariable ["varsByScope", _variablesByScope] };

                        _variablesByScope pushback [];
                    };
                    case "leaving": {
                        private _variablesByScope = _visitor getvariable "varsByScope";

                        // remove definitions of single-use definitions

                        _visitor setvariable ["inOptimizationPass", true];
                        // revisit child nodes to transform them
                        private _statementList = _node select 1;
                        { VISIT(_x) } foreach _statementList;
                        _visitor setvariable ["inOptimizationPass", false];

                        private _variablesByScope = _visitor getvariable "varsByScope";
                        private _lastScopeIndex = (count _variablesByScope) - 1;
                        _variablesByScope deleteat _lastScopeIndex;
                    };
                };
            };
        }],
        ["assignment", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _varDefinitionNode = _node select 1;
            private _right = _node select 3;

            private _inOptimizationPass = _visitor getvariable ["inOptimizationPass",false];

            if (!_inOptimizationPass) then {
                // keep track of variable definition and assigned value

                private _varToken = _varDefinitionNode select 1;
                private _varName = _varToken select 1;
                private _varProperties = _varDefinitionNode select 2;

                if !("global" in _varProperties) then {
                    private _variablesByScope = _visitor getvariable "varsByScope";
                    private _lowestScope = _variablesByScope select ((count _variablesByScope) - 1);
                    _lowestScope pushback [_varName,-1,_right]; // start at -1 because var definition counts as one use too
                };
            } else {
                private _varToken = _varDefinitionNode select 1;
                private _varName = _varToken select 1;

                private _variablesByScope = _visitor getvariable "varsByScope";

                private _varUseData = [_variablesByScope,_varName] call _findVarUsageData;
                private _timesVarUsed = _varUseData select 1;

                // remove assignment statement if var only used once
                if (_timesVarUsed == 1) then {
                    _node set [0,"no_statement"];
                    for "_i" from 1 to (count _node - 1) do {
                        _node deleteat _i;
                    };
                };
            };
        }],
        ["identifier", {
            params ["_node","_visitor","_state"];

            if (_state != "leaving") exitwith {};

            private _varName = _node select 1;

            private _variablesByScope = _visitor getvariable "varsByScope";
            private _varUseData = [_variablesByScope,_varName] call _findVarUsageData;

            if (!isnil "_varUseData") then {
                private _inOptimizationPass = _visitor getvariable ["inOptimizationPass",false];
                private _timesVarUsed = _varUseData select 1;

                if (!_inOptimizationPass) then {
                    _varUseData set [1, _timesVarUsed + 1];
                } else {
                    if (_timesVarUsed == 1) then {
                        // substitute expression for variable

                        private _expression = _varUseData select 2;
                        {
                            _node set [_foreachindex, _x];
                        } foreach _expression;
                    };
                };
            };
        }]
    ]] call sqfpp_fnc_transform;
};


// we can also abuse scope bleed here
// any var defined in class_def will remain defined for the other two node types if valid
// and will go out of scope once the class_def node is left
sqfpp_fnc_transformClassSelfReferences = {
    private _tree = _this;

    [_tree,[
        ["class_definition", {
            params ["_node","_visitor","_state"];

            private _inClassDef = _visitor getvariable ["inClassDef", false];

            switch (_state) do {
                case "entered": {
                    _visitor setvariable ["inClassDef", true];

                    _node params ["_type","_classname","_parents","_varNodes","_funcNodes"];

                    // manually visit function nodes so
                    // we know when we're inside one
                    {
                        _x params ["_name","_parameters","_body"];

                        _visitor setVariable ["inClassMethod", true];
                        VISIT(_body);
                        _visitor setVariable ["inClassMethod", false];
                    } foreach _funcNodes;
                };
                case "leaving": {
                    _visitor setvariable ["inClassDef", false];
                };
            };
        }],
        ["identifier", {
            params ["_node","_visitor","_state"];

            private _inClassMethod = _visitor getvariable ["inClassMethod", false];

            if (_inClassMethod) then {
                private _content = _node select 1;

                if (_content == "this") then {
                    _node set [1,"__sqfpp_this"];
                };
            };
        }]
    ]] call sqfpp_fnc_transform;
};


sqfpp_fnc_transformLocalVariables = {
    private _tree = _this;

    [_tree,[
        ["block", {
            params ["_node","_visitor","_state"];

            // keep track of variables by scope

            switch (_state) do {
                case "entered": {
                    private _variablesByScope = _visitor getvariable "varsByScope";
                    if (isnil "_variablesByScope") then { _variablesByScope = []; _visitor setvariable ["varsByScope", _variablesByScope] };

                    _variablesByScope pushback [];
                };
                case "leaving": {
                    private _variablesByScope = _visitor getvariable "varsByScope";
                    private _lastScopeIndex = (count _variablesByScope) - 1;
                    _variablesByScope deleteat _lastScopeIndex;
                };
            };
        }],
        ["variable_definition", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _varToken = _node select 1;
            private _varName = _varToken select 1;
            private _varProperties = _node select 2;

            if ("global" in _varProperties) exitwith {};

            private _variablesByScope = _visitor getvariable "varsByScope";
            if (isnil "_variablesByScope") exitwith {};

            private _lowestScope = _variablesByScope select ((count _variablesByScope) - 1);
            _lowestScope pushback _varName;
        }],
        ["named_function", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _variablesByScope = _visitor getvariable "varsByScope";
            if (isnil "_variablesByScope") exitwith {};

            private _parameterList = _node select 2;
            private _definedVariables = _parameterList apply {_x select 2};

            private _lowestScope = _variablesByScope select ((count _variablesByScope) - 1);
            _lowestScope append _definedVariables;
        }],
        ["identifier", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _varName = _node select 1;

            private _variablesByScope = _visitor getvariable "varsByScope";
            if (isnil "_variablesByScope") exitwith {};

            private _varInScope = (_variablesByScope findif {_varName in _x}) != -1;
            if (_varInScope) then {
                private _localVarName = "_" + _varName;
                _node set [1,_localVarName];
            };
        }]
    ]] call sqfpp_fnc_transform;
};


sqfpp_fnc_transformNamespaceAccess = {
    private _tree = _this;

    [_tree,[
        ["namespace_block", {
            params ["_node","_visitor","_state"];

            if (_state == "leaving") then {
                _node params ["_type","_namespace","_blockNodes"];

                // sub namespace blocks will be turned into block nodes
                // take the nodes from these blocks and merge them into this block

                private _newNodes = [];
                {
                    private _isBlockNode = (_x select 0) == "block";

                    if (_isBlockNode) then {
                        _newNodes append (_x select 1);
                    } else {
                        _newNodes pushback _x;
                    };
                } foreach _blockNodes;
                _blockNodes = _newNodes;

                {
                    private _nodeType = _x select 0;

                    switch (_nodeType) do {
                        case "expression_statement": {
                            private _assignmentNode = _x select 1;
                            private _varDefNode = _assignmentNode select 1;
                            private _varDefToken = _varDefNode select 1;
                            private _varDefName = _varDefToken select 1;

                            private _newVarDefName = _namespace + "_" + _varDefName;
                            _varDefToken set [1, _newVarDefName];
                        };
                        case "assignment": {
                            private _varDefNode = _x select 1;
                            private _varDefToken = _varDefNode select 1;
                            private _varDefName = _varDefToken select 1;

                            private _newVarDefName = _namespace + "_" + _varDefName;
                            _varDefToken set [1, _newVarDefName];
                        };
                        case "named_function": {
                            private _functionName = _x select 1;
                            private _newFunctionName = _namespace + "_" + _functionName;

                            _x set [1, _newFunctionName];
                        };
                        case "class_definition": {
                            private _className = _x select 1;
                            private _newClassName = _namespace + "_" + _className;

                            _x set [1, _newClassName];
                        };
                    };
                } foreach _blockNodes;

                _node set [0, "block"];
                _node set [1, _blockNodes];
                _node deleteat 2;
            };
        }],
        ["namespace_accessor", {
            params ["_node","_visitor","_state"];

            if (_state == "leaving") then {
                private _left = _node select 1;
                private _right = _node select 2;

                // merge left identifier into right node
                // transform this node into the updated right node

                private _namespace = _left select 1;
                private _rightNodeType = _right select 0;
                private _rightNodeText = _right select 1;

                private _prefix = _namespace + "_";
                if (_rightNodeType == "function_call") then {
                    _prefix = _prefix + "fnc_";
                };

                private _newRightNodeName = _prefix + _rightNodeText;

                _node set [0, _rightNodeType];
                _node set [1, _newRightNodeName];

                for "_i" from 2 to (count _right - 1) do {
                    _node set [_i, _right select _i];
                };
            };
        }]
    ]] call sqfpp_fnc_transform;
};


sqfpp_fnc_transformContinuedLoops = {
    private _tree = _this;

    private _inLoop = {
        params ["_node","_visitor","_state"];

        private _inLoopCount = _visitor getvariable ["inLoopCount", 0];

        switch (_state) do {
            case "entered": {
                _visitor setvariable ["inLoopCount", _inLoopCount + 1];
            };
            case "leaving": {
                private _continueFound = _visitor getvariable ["continueFound", false];

                if (_continueFound) then {
                    private _nodeType = _node select 0;
                    switch (_nodeType) do {
                        case "while": {
                            _node set [3, true];
                        };
                        case "for": {
                            _node set [5, true];
                        };
                        case "foreach": {
                            _node set [4, true];
                        };
                    };
                };

                _visitor setvariable ["continueFound", false];
                _visitor setvariable ["inLoopCount", _inLoopCount - 1];
            };
        };
    };

    [_tree,[
        ["while", _inLoop],
        ["for", _inLoop],
        ["foreach", _inLoop],
        ["continue", {
            private _inLoopCount = _visitor getvariable ["inLoopCount", 0];

            if (_inLoopCount > 0) then {
                _visitor setvariable ["continueFound", true];
            };
        }]
    ]] call sqfpp_fnc_transform;
};


sqfpp_fnc_transformClassMemberAccess = {
    private _tree = _this;

    [_tree,[
        ["class_definition", {
            params ["_node","_visitor","_state"];

            if (_state == "leaving") exitwith {
                _visitor setvariable ["memberVars", []];
            };

            _node params ["_type","_classname","_parents","_varNodes","_funcNodes"];

            private _classTemplate = _classname call soop_fnc_getClassTemplate;
            private _classVariables = _classTemplate getvariable "sqfpp__VARIABLES";
            private _classMethods = _classTemplate getvariable "sqfpp__METHODS";

            _visitor setvariable ["memberVars", _classVariables];
            _visitor setvariable ["memberFuncs", _classMethods];

            // manually visit nodes to more easily
            // handle restricted vars by method
            {
                _x params ["_name","_parameters","_body"];

                private _restrictedVars = _parameters apply {_x select 2};
                _visitor setVariable ["restrictedVars", _restrictedVars];

                _visitor setVariable ["currentMethod", _name];
                VISIT(_body);
                _visitor setVariable ["currentMethod", nil];
            } foreach _funcNodes;
        }],
        ["variable_definition", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _varToken = _node select 1;
            private _varName = _varToken select 1;

            private _restrictedVars = _visitor getvariable "restrictedVars";
            _restrictedVars pushbackunique _varName;
        }],
        ["named_function", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _definedFunctionName = _node select 1;

            private _restrictedVars = _visitor getvariable "restrictedVars";
            _restrictedVars pushbackunique _definedFunctionName;
        }],
        ["class_access", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _object = _node select 1;
            private _objectString = _object select 1;

            if (_objectString == "this") then {
                _visitor setvariable ["ignoreNextThis", true];
            };
        }],
        ["method_call", {
            params ["_node","_visitor","_state"];

            if (_state != "entered") exitwith {};

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _object = _node select 1;
            private _objectString = _object select 1;

            if (_objectString == "this") then {
                _visitor setvariable ["ignoreNextThis", true];
            };
        }],
        ["function_call", {
            params ["_node","_visitor","_state"];

            if (_state != "leaving") exitwith {};

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _functionName = _node select 1;

            private _restrictedVars = _visitor getvariable "restrictedVars";
            private _classMethods = _visitor getvariable "memberFuncs";
            private _classMemberVars = _visitor getvariable "memberVars";

            private _varIsRestricted = _functionName in _restrictedVars;
            private _varIsMember = _functionName in _classMethods || { _functionName in _classMemberVars };

            if (!_varIsRestricted && _varIsMember) then {
                private _ignoreNextThis = _visitor getvariable ["ignoreNextThis", false];
                if (_ignoreNextThis) exitwith { _visitor setvariable ["ignoreNextThis", false] };

                // transform function call into method call

                private _instanceVar = ["identifier", [ ["identifier","this"] ]] call sqfpp_fnc_createNode;
                private _methodName = _node select 1;
                private _methodArgs = _node select 2;

                _node set [0, "method_call"];
                _node set [1, _instanceVar];
                _node set [2, _methodName];
                _node set [3, _methodArgs];
            };
        }],
        ["identifier", {
            params ["_node","_visitor","_state"];

            if (_state != "leaving") exitwith {};

            private _varName = _node select 1;

            private _currentMethod = _visitor getvariable "currentMethod";
            if (isnil "_currentMethod") exitwith {};

            private _restrictedVars = _visitor getvariable "restrictedVars";
            private _classMemberVars = _visitor getvariable "memberVars";

            private _varIsRestricted = _varName in _restrictedVars;
            private _varIsMember = _varName in _classMemberVars;

            if (!_varIsRestricted && _varIsMember) then {
                private _ignoreNextThis = _visitor getvariable ["ignoreNextThis", false];
                if (_ignoreNextThis) exitwith { _visitor setvariable ["ignoreNextThis", false] };

                // transform _node into class access
                private _instanceVar = ["identifier", [ ["identifier","this"] ]] call sqfpp_fnc_createNode;
                private _varIdentifier = +_node;

                _node set [0, "class_access"];
                _node set [1, _instanceVar];
                _node set [2, _varIdentifier];
            };
        }]
    ]] call sqfpp_fnc_transform;
};

/*

["block",[
    ["expression_statement",
        ["method_call",
            ["identifier","this",[]],
            "varname",
            []
        ]
    ]
]]

["block",[
    ["expression_statement",
        ["assignment",
            ["identifier","_x","var"],
            "=",
            ["class_access",
                ["identifier","this",[]],
                ["identifier","varname",[]]
            ]
        ]
    ]
]]

*/




/*
sqfpp_fnc_transformContinueStatements = {
    private _tree = _this;

    [_tree,[
        ["block", {
            params ["_node","_visitor","_state"];

            if (_state == "entered") then {
                private _blockStatements = _node select 1;

                private _i = 0;
                private _blockStatementsCount = count _blockStatements;

                while {_i < _blockStatementsCount} do {
                    private _outerStatement = _blockStatements select _i;
                    private _outerStatementType = _outerStatement select 0;

                    if (_outerStatementType == "if") then {
                        private _trueBlock = _outerStatement select 2;
                        private _trueBlockStatements = _trueBlock select 1;

                        private _innerStatement = _trueBlockStatements select 0;
                        private _innerStatementType = _innerStatement select 0;

                        if (_innerStatementType == "continue") then {
                            // negate condition
                            // surround all remaining statements from the outer block

                            private _condition = _outerStatement select 1;
                            private _negatedCondition = ["unary_operation", ["!", _condition]] call sqfpp_fnc_createNode;

                            private _countRemainingStatements = _blockStatementsCount - _i;
                            private _statementsToSurround = _blockStatements select [_i + 1, _countRemainingStatements];
                            _blockStatements deleterange [_i + 1, _countRemainingStatements];
                            _blockStatementsCount = _i;

                            private _surroundedStatements = ["block", [_statementsToSurround]] call sqfpp_fnc_createNode;

                            _outerStatement set [1,_negatedCondition];
                            _outerStatement set [2,_surroundedStatements];
                        };
                    };

                    _i = _i + 1;
                };
            };
        }]
    ]] call sqfpp_fnc_transform;
};
*/