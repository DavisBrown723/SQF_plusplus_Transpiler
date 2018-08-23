sqfpp_fnc_compile = {
    params ["_sourceText", ["_compile", true]];

    private _ast = _sourceText call sqfpp_fnc_parse;

    // #TODO
    parsed = _ast;


    private _code = _ast call sqfpp_fnc_translateNode;
    _code = format ["scopename '___functionScope___'; %1", _code];

    if (_compile) then { compile _code } else { _code }
};

sqfpp_fnc_compileFile = {
    params ["_file", ["_compile", true]];

    private _sourceText = preprocessFile _file;

    [_sourceText,_compile] call sqfpp_fnc_compile
};

sqfpp_fnc_loadClassFile = {
    params ["_file"];

    private _sourceText = preprocessFile _file;

    // execute translated file
    // to load class definition to missionnamespace

    call ([_sourceText,_compile] call sqfpp_fnc_compile)
};



sqfpp_fnc_parameterListToString = {
    private _parameterString = "";
    {
        if (_foreachindex > 0) then {_parameterString = _parameterString + ","};
        _parameterString = _parameterString + (_x call sqfpp_fnc_translateNode);
    } foreach _this;

    _parameterString
};




sqfpp_fnc_translateNode = {
    scopename "translateNode";

    private _node = _this;
    private _nodeType = _node select 0;

    switch (_nodeType) do {

        case "identifier": {
            private _identifier = _node select 1;

            private _code = _identifier;
            _code breakout "translateNode";
        };

        case "literal": {
            private _literalToken = _node select 1;

            _literalToken params ["_literalType","_literalValue"];

            if (_literalType == "array_literal") then {
                private _translatedElements = _literalValue apply {_x call sqfpp_fnc_translateNode};
                private _code = "[" + (_translatedElements joinstring ",") + "]";

                _code breakout "translateNode";
            };

            private _code = _literalValue;
            _code breakout "translateNode";
        };

        case "expression_statement": {
            private _expression = _node select 1;

            private _code = format ["%1;", _expression call sqfpp_fnc_translateNode];

            _code breakout "translateNode";
        };

        case "block": {
            private _containedNodes = _node select 1;

            private _code = "";
            { _code = _code + (_x call sqfpp_fnc_translateNode) } foreach _containedNodes;

            _code breakout "translateNode";
        };

        // this is only called when a value has not been given
        case "variable_definition": {
            private _definedVarToken = _node select 1;

            private _code = format ["private '%1'", _definedVarToken call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

        case "assignment": {
            private _left = _node select 1;
            private _operator = _node select 2;
            private _right = _node select 3;

            if (_operator == "=") then {
                private _code = switch (_left select 0) do {
                    case "variable_definition": {
                        private _definedVarToken = _left select 1;
                        private _definedVar = _definedVarToken select 1;
                        private _definedVarIsLocal = (_definedVar select [0,1]) == "_";

                        private _prefix = if (_definedVarIsLocal) then { "private " } else { "" };

                        format ["%1%2 = %3", _prefix, _definedVar, _right call sqfpp_fnc_translateNode];
                    };
                    case "class_access": {
                        private _object = _left select 1;
                        private _member = _left select 2;

                        format ["%1 setvariable ['%2',%3]", _object call sqfpp_fnc_translateNode, _member call sqfpp_fnc_translateNode, _right call sqfpp_fnc_translateNode];
                    };
                    default {
                        format ["%1 = %2", _left call sqfpp_fnc_translateNode, _right call sqfpp_fnc_translateNode];
                    };
                };

                _code breakout "translateNode";
            } else {
                private _assignmentOperation = _operator select [0,1];
                private _code = format ["%1 = %1 %2 %3", _left call sqfpp_fnc_translateNode, _assignmentOperation, _right call sqfpp_fnc_translateNode];

                _code breakout "translateNode";
            };
        };

        /*
            function = {
                scopename "___functionScope___";

                while (true) do {
                    scopename "___loopScope___";

                    if (true) then {
                        breakout "___loopScope___";
                    };
                };
            };
        */

        case "break": {
            private _code = "breakout '___loopScope___';";
            _code breakout "translateNode";
        };

        /*
            function = {
                scopename "___functionScope___";

                while (true) do {
                    scopename "___loopScope___";

                    call {
                        if (true) then {
                            breakto "___loopScope___";
                        };
                    };
                };
            };
        */


        case "continue": {
            private _code = "breakto '___loopScope___';";
            _code breakout "translateNode";
        };

        case "return": {
            private _expression = _node select 1;

            private _noReturnValue = _expression isequalto [];

            private _toReturn = if (_noReturnValue) then { "" } else { (_expression call sqfpp_fnc_translateNode) + " "};

            private _code = format ["%1breakout '___functionScope___';", _toReturn];
            _code breakout "translateNode";
        };

        case "unary_operation": {
            private _operator = _node select 1;
            private _right = _node select 2;

            private _code = format ["(%1%2)", _operator, _right call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

        case "binary_operation": {
            private _operator = _node select 1;
            private _left = _node select 2;
            private _right = _node select 3;

            private _operatorInfo = _operator call sqfpp_fnc_getOperatorInfo;
            private _operatorAttributes = _operatorInfo select 3;

            private _code = format ["(%1 %2 %3)", _left call sqfpp_fnc_translateNode, _operator, _right call sqfpp_fnc_translateNode];

            _code breakout "translateNode";
        };

        case "if": {
            private _condition = _node select 1;
            private _trueBlock = _node select 2;
            private _falseBlock = _node select 3;

            private _code = format ["if (%1) then {%2}", _condition call sqfpp_fnc_translateNode, _trueBlock call sqfpp_fnc_translateNode];

            if !(_falseBlock isequalto []) then {
                _code = _code + format [" else {%1}", _falseBlock call sqfpp_fnc_translateNode];
            };

            // close ending block
            _code = _code + ";";

            _code breakout "translateNode";
        };

        case "while": {
            private _condition = _node select 1;
            private _block = _node select 2;
            private _needsScopeWrap = _node select 3;

            private _loopInternal = "scopename '___loopScope___'";
            if (_needsScopeWrap) then {
                _loopInternal = format ["%1; call {%2};", _loopInternal, _block call sqfpp_fnc_translateNode];
            } else {
                _loopInternal = format ["%1; %2", _loopInternal, _block call sqfpp_fnc_translateNode];
            };

            private _code = format ["while {%1} do {%2};", _condition call sqfpp_fnc_translateNode, _loopInternal];

            _code breakout "translateNode";
        };

        case "for": {
            private _pre = _node select 1;
            private _condition = _node select 2;
            private _post = _node select 3;
            private _block = _node select 4;
            private _needsScopeWrap = _node select 5;

            private _loopPrefix = "scopename '___loopScope___'";
            private _loopInternal = format ["%1%2", _block call sqfpp_fnc_translateNode, _post call sqfpp_fnc_translateNode];
            if (_needsScopeWrap) then {
                _loopInternal = format ["%1; call {%2};", _loopPrefix, _loopInternal];
            } else {
                _loopInternal = format ["%1; %2", _loopPrefix, _loopInternal];
            };

            private _code = format [
                "%1 while {%2} do {%3};",
                _pre call sqfpp_fnc_translateNode,
                _condition call sqfpp_fnc_translateNode,
                _loopInternal
            ];

            _code breakout "translateNode";
        };

        case "foreach": {
            private _list = _node select 1;
            private _enumerableVar = _node select 2;
            private _block = _node select 3;
            private _needsScopeWrap = _node select 4;

            private _loopPrefix = "scopename '___loopScope___'";
            private _loopInternal = format ["private %1 = _x;%2", _enumerableVar call sqfpp_fnc_translateNode, _block call sqfpp_fnc_translateNode];
            if (_needsScopeWrap) then {
                _loopInternal = format ["%1; call {%2};", _loopPrefix, _loopInternal];
            } else {
                _loopInternal = format ["%1; %2", _loopPrefix, _loopInternal];
            };

            private _code = format ["{%1} foreach %2;", _loopInternal, _list call sqfpp_fnc_translateNode];

            _code breakout "translateNode";
        };

        case "switch": {
            private _condition = _node select 1;
            private _cases = _node select 2;

            private _code = format ["switch (%1) do { scopename '___loopScope___'; ", _condition call sqfpp_fnc_translateNode];

            {
                _x params ["_caseCondition","_caseBlock"];

                if (_caseCondition isequalto []) then {
                    _code = _code + (format ["default {%1};", _caseBlock call sqfpp_fnc_translateNode]);
                } else {
                    _code = _code + (format ["case %1: {%2};", _caseCondition call sqfpp_fnc_translateNode, _caseBlock call sqfpp_fnc_translateNode]);
                };
            } foreach _cases;

            _code = _code + "};";

            _code breakout "translateNode";
        };

        case "class_access": {
            private _object = _node select 1;
            private _member = _node select 2;

            private _code = format ["(%1 getvariable '%2')", _object call sqfpp_fnc_translateNode, _member call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

        case "method_call": {
            private _object = _node select 1;
            private _method = _node select 2;
            private _arguments = _node select 3;

            _object = _object call sqfpp_fnc_translateNode;

            // methods take class instance as first argument
            // manually inject it
            _arguments = _arguments apply {_x call sqfpp_fnc_translateNode};
            _arguments = [_object] + _arguments;
            _arguments = "[" + (_arguments joinstring ",") + "]";

            private _code = format ["(%1 call (%2 getvariable '%3'))", _arguments, _object, _method];
            _code breakout "translateNode";
        };

        case "function_call": {
            private _function = _node select 1;
            private _arguments = _node select 2;

            private _argumentCount = count _arguments;

            // determine if function is SQF command

            private _nularIndex = (sqfpp_sqfCommandsByType select 0) findif {_function == _x};
            if (_nularIndex != -1 && {_argumentCount == 0}) then {
                private _code = _function;
                _code breakout "translateNode";
            };

            private _unaryIndex = (sqfpp_sqfCommandsByType select 1) findif {_function == _x};
            if (_unaryIndex != -1 && {_argumentCount == 1}) then {
                private _rhs = (_arguments select 0) call sqfpp_fnc_translateNode;

                private _code = format ["(%1 %2)", _function, _rhs];
                _code breakout "translateNode";
            };

            private _binaryIndex = (sqfpp_sqfCommandsByType select 2) findif {_function == _x};
            if (_binaryIndex != -1 && {_argumentCount == 2}) then {
                _arguments params ["_argLeft","_argRight"];
                private _code = format ["(%1 %2 %3)", _argLeft call sqfpp_fnc_translateNode, _function, _argRight call sqfpp_fnc_translateNode];
                _code breakout "translateNode";
            };

            // function call

            _arguments = _arguments apply {_x call sqfpp_fnc_translateNode};
            _arguments = "[" + (_arguments joinstring ",") + "]";

            private _code = format ["(%1 call %2)", _arguments, _function];
            _code breakout "translateNode";
        };

        case "unnamed_scope": {
            private _block = _node select 1;

            private _code = "call {" + (_block call sqfpp_fnc_translateNode) + "};";
            _code breakout "translateNode";
        };

        case "lambda": {
            private _parameters = _node select 1;
            private _body = _node select 2;

            private _parameterString = _parameters call sqfpp_fnc_parameterListToString;
            private _paramsString = if (_parameterString == "") then {""} else {format ["params [%1];", _parameterString]};

            private _code = format ["{scopename '___functionScope___'; %1 %2}", _paramsString, _body call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

        case "function_parameter": {
            private _validTypes = _node select 1;
            private _varname = _node select 2;
            private _defaultValue = _node select 3;

            _defaultValue = if (_defaultValue isequalto "sqfpp_defValue") then {"nil"} else {_defaultValue call sqfpp_fnc_translateNode};
            _validTypes = _validTypes apply { _x call sqfpp_fnc_typeToSQFType };

            private _validTypesStr = "[";
            {
                if (_foreachindex > 0) then {_validTypesStr = _validTypesStr + ","};
                _validTypesStr = _validTypesStr + _x;
            } foreach _validTypes;
            _validTypesStr = _validTypesStr + "]";

            private _code = format ["['%1',%2,%3]", _varname, _defaultValue, _validTypesStr];
            _code breakout "translateNode";
        };

        case "named_function": {
            private _function = _node select 1;
            private _parameters = _node select 2;
            private _body = _node select 3;

            private _parameterString = _parameters call sqfpp_fnc_parameterListToString;
            private _paramsString = if (_parameterString == "") then {""} else {format ["params [%1];", _parameterString]};

            private _code = format ["%1 = {scopename '___functionScope___'; %2 %3};", _function, _paramsString, _body call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

        case "raw_sqf": {
            private _tokens = _node select 1;

            private _code = "";
            {
                _code = _code + (_x select 1) + " ";
            } foreach _tokens;

            _code breakout "translateNode";
        };

        case "class_definition": {
            private _classname = _node select 1;
            private _parents = _node select 2;
            private _variables = _node select 3;
            private _functions = _node select 4;

            private _code = "call {";
            _code = _code + (format ["private _classname = %1;", str _classname]);

            _code = _code + "private _parents = [";
            if !(_parents isequalto []) then {
                {
                    if (_foreachindex != 0) then {_code = _code + ","};
                    _code = _code + (str _x);
                } foreach _parents;
            };
            _code = _code + "];";

            _code = _code + "private _classVariables = [];";
            {
                _code = _code + (format ["_classVariables pushback ['%1',%2];", _x select 0, (_x select 1) call sqfpp_fnc_translateNode]);
            } foreach _variables;

            _code = _code + "private _classMethods = [];";
            {
                _x params ["_name","_parameters","_body"];

                private _parameterString = _parameters call sqfpp_fnc_parameterListToString;
                private _paramsString = if (_parameterString == "") then {""} else {format ["params [%1];", _parameterString]};

                _code = _code + (format ["_classMethods pushback ['%1',{scopename '___functionScope___'; %2 %3}];", _name, _paramsString, _body call sqfpp_fnc_translateNode]);
            } foreach _functions;

            _code = _code + "[_classname,_parents,_classVariables,_classMethods] call soop_fnc_defineClass";

            _code = _code + "};";
            _code breakout "translateNode";
        };

        case "new_instance": {
            private _class = _node select 1;
            private _arguments = _node select 2;

            _arguments = _arguments apply {_x call sqfpp_fnc_translateNode};
            _arguments = "[" + (_arguments joinstring ",") + "]";

            private _code = format ["(['%1',%2] call soop_fnc_newInstance)", _class, _arguments];
            _code breakout "translateNode";
        };

        case "delete_instance": {
            private _instance = _node select 1;

            private _code = format ["(%1 call soop_fnc_deleteInstance)", _instance call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };
        case "copy_instance": {
            private _instance = _node select 1;

            private _code = format ["(%1 call soop_fnc_copyInstance)", _instance call sqfpp_fnc_translateNode];
            _code breakout "translateNode";
        };

    };

    ""
};