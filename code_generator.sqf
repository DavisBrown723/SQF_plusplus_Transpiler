translateNode = {
    private _node = _this;

    scopename "translateNode";

    switch (_node select 0) do {

        case "expression_statement": {
            private _expression = _node select 1;

            private _code = format ["%1;", _expression call translateNode];

            _code breakout "translateNode";
        };

        case "block": {
            private _blockNodes = _node select 1;

            private _code = "";
            {
                private _nodeCode = _x call translateNode;
                _code = _code + _nodeCode;
            } foreach _blockNodes;

            _code breakout "translateNode";
        };

        case "identifier": {
            private _token = _node select 1;
            private _literal = _token select 1;

            private _code = _literal;
            _code breakout "translateNode";
        };

        case "literal": {
            private _token = _node select 1;
            private _literal = _token select 1;

            if ((_token select 0) == "array_literal") then {
                private _elements = _literal apply {_x call translateNode};
                private _code = "[" + (_elements joinstring ",") + "]";

                _code breakout "translateNode";
            };

            private _code = _literal;
            _code breakout "translateNode";
        };

        case "assignment": {
            private _keywords = _node select 1;
            private _operator = _node select 2;
            private _left = _node select 3;
            private _right = _node select 4;

            private _code = "";

            if ("var" in _keywords) then {
                _code = _code + "private ";
            };

            if (_right isequalto "__PARSER_DEFINITION") then {
                _code = _code + (format ["'%1';", _left call translateNode]);
            } else {
                if (_operator == "=") then {
                    // =
                    _code = _code + (format ["%1 %2 %3;", _left call translateNode, _operator, _right call translateNode]);
                } else {
                    // +=, *=
                    private _operatorOperation = _operator select [0,1];
                    _code = _code + (format ["%1 = %1 %2 %3;", _left call translateNode, _operatorOperation, _right call translateNode]);
                };
            };

            _code breakout "translateNode";
        };

        case "nular_statement": {
            private _symbol = _node select 1;

            switch (_symbol) do {
                case "break": {
                    private _code = "breakto 'sqf_pp_nearestLoopScope';";
                    _code breakout "translateNode";
                };
                default {
                    private _code = _symbol;
                    _code breakout "translateNode";
                };
            };
        };

        case "unary_statement": {
            private _symbol = _node select 1;

            switch (_symbol) do {
                case "return": {
                    private _expression = _node select 2;

                    private _arg = if (_expression isequalto []) then {
                        ""
                    } else {
                        _expression call translateNode
                    };

                    private _code = format ["%1 breakout 'sqf_pp_function_scope';", _arg];

                    _code breakout "translateNode";
                };
                default {
                    private _code = _symbol;
                    _code breakout "translateNode";
                };
            };
        };

        case "unary": {
            private _operator = _node select 1;
            private _right = _node select 2;

            private _code = format ["(%1 %2)", _operator, _right call translateNode];
        };

        case "binary": {
            private _operator = _node select 1;
            private _left = _node select 2;
            private _right = _node select 3;

            private _code = switch (_operator) do {
                /*
                case ".": {
                    if ((_right select 0) == "function_call") then {
                        _right set [0,"method_call"];

                        // extract method call info

                        private _methodname = _right select

                        // this.method()
                        // left: this
                        // right: [] call method
                        format ["( (%1 getvariable ) )"];
                    } else {
                        format ["(%1 getvariable '%2')", _left call translateNode, _right call translateNode];
                    };
                };
                */
                default {
                    format ["(%1 %2 %3)", _left call translateNode, _operator, _right call translateNode];
                };
            };

            _code breakout "translateNode";
        };

        case "if": {
            private _condition = _node select 1;
            private _trueBlock = _node select 2;
            private _falseBlock = _node select 3;

            private _code = format ["if (%1) then {%2};", _condition call translateNode, _trueBlock call translateNode];

            if !(_falseBlock isequalto []) then {
                _code = _code + format [" else {%1};", _falseBlock call translateNode];
            };

            _code breakout "translateNode";
        };

        case "while": {
            private _condition = _node select 1;
            private _block = _node select 2;

            private _code = format ["scopename 'sqf_pp_nearestLoopScope';while {%1} do {%2};", _condition call translateNode, _block call translateNode];

            _code breakout "translateNode";
        };

        case "for": {
            private _pre = _node select 1;
            private _condition = _node select 2;
            private _post = _node select 3;
            private _block = _node select 4;

            private _code = format [
                "%1 scopename 'sqf_pp_nearestLoopScope';while {%2} do {%3%4};",
                _pre call translateNode, _condition call translateNode, _block call translateNode, _post call translateNode
            ];

            _code breakout "translateNode";
        };

        case "foreach": {
            private _list = _node select 1;
            private _enumerableVar = _node select 2;
            private _block = _node select 3;

            private _code = format [
                "scopename 'sqf_pp_nearestLoopScope'; {private %1 = _x;%2} foreach %3;",
                _enumerableVar call translateNode, _block call translateNode, _list call translateNode
            ];

            _code breakout "translateNode";
        };

        case "switch": {
            private _condition = _node select 1;
            private _cases = _node select 2;

            private _code = format ["scopename 'sqf_pp_nearestLoopScope'; switch (%1) do {", _condition call translateNode];

            {
                _x params ["_caseCondition","_caseBlock"];

                if (_caseCondition isequalto []) then {
                    _code = _code + (format ["default {%1};", _caseBlock call translateNode]);
                } else {
                    _code = _code + (format ["case %1: {%2};", _caseCondition call translateNode, _caseBlock call translateNode]);
                };
            } foreach _cases;

            _code = _code + "};";

            _code breakout "translateNode";
        };

        case "class_access": {
            private _object = _node select 1;
            private _member = _node select 2;

            private _code = format ["(%1 getvariable %2)", _object call translateNode, _member call translateNode];
            _code breakout "translateNode";
        };

        case "method_call": {
            private _object = _node select 1;
            private _method = _node select 2;
            private _arguments = _node select 3;

            _arguments = _arguments apply {_x call translateNode};
            _arguments = "[" + (_arguments joinstring ",") + "]";

            // #TODO: Remove the temporary this variable swap
            private _code = format ["(%1 call (%2 getvariable '%3'))", _arguments, _object call translateNode, _method];
            _code breakout "translateNode";
        };

        case "function_call": {
            private _function = _node select 1;
            private _arguments = _node select 2;

            // determine if function is SQF command

            private _nularIndex = (sqfCommands select 0) findif {_function == _x};
            if (_nularIndex != -1) then {
                private _code = _function;
                _code breakout "translateNode";
            };

            private _unaryIndex = (sqfCommands select 1) findif {_function == _x};
            if (_unaryIndex != -1) then {
                private _rhs = (_arguments select 0) call translateNode;

                private _code = format ["(%1 %2)", _function, _rhs];
                _code breakout "translateNode";
            };

            private _binaryIndex = (sqfCommands select 2) findif {_function == _x};
            if (_binaryIndex != -1) then {
                _arguments params ["_argLeft","_argRight"];
                private _code = format ["(%1 %2 %3)", _argLeft call translateNode, _function, _argRight call translateNode];
                _code breakout "translateNode";
            };

            // function call

            _arguments = _arguments apply {_x call translateNode};
            _arguments = "[" + (_arguments joinstring ",") + "]";

            private _code = format ["(%1 call %2)", _arguments, _function];
            _code breakout "translateNode";
        };

        case "unnamed_scope": {
            private _block = _node select 1;

            private _code = "call {" + (_block call translateNode) + "};";
            _code breakout "translateNode";
        };

        case "lambda": {
            private _body = _node select 1;

            private _code = format ["{scopename 'sqf_pp_function_scope'; _this call {%1}}", _body call translateNode];
            _code breakout "translateNode";
        };

        case "function_parameter": {
            private _validTypes = _node select 1;
            private _varname = _node select 2;
            private _defaultValue = _node select 3;

            _defaultValue = if (_defaultValue isequalto "sqfpp_defValue") then {nil} else {_defaultValue call translateNode};
            _validTypes = _validTypes apply { _x call typeToSQFType };

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

            private _parameterString = "";
            {
                if (_foreachindex > 0) then {_parameterString = _parameterString + ", "};
                _parameterString = _parameterString + (_x call translateNode);
            } foreach _parameters;

            private _code = format ["%1 = {scopename 'sqf_pp_function_scope'; _this call {params [%2]; %3}};", _function, _parameterString, _body call translateNode];
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
                _code = _code + (format ["_classVariables pushback ['%1',%2];", _x select 0, (_x select 1) call translateNode]);
            } foreach _variables;

            _code = _code + "private _classMethods = [];";
            {
                _code = _code + (format ["_classMethods pushback ['%1',{scopename 'sqf_pp_function_scope'; %2}];", _x select 0, (_x select 1) call translateNode]);
            } foreach _functions;

            _code = _code + "[_classname,_parents,_classVariables,_classMethods] call soop_fnc_defineClass";

            _code = _code + "};";
            _code breakout "translateNode";
        };

        case "new_instance": {
            private _class = _node select 1;
            private _arguments = _node select 2;

            _arguments = _arguments apply {_x call translateNode};
            _arguments = "[" + (_arguments joinstring ",") + "]";

            private _code = format ["(['%1',%2] call soop_fnc_newInstance)", _class, _arguments];
            _code breakout "translateNode";
        };

        case "delete_instance": {
            private _instance = _node select 1;

            private _code = format ["(%1 call soop_fnc_deleteInstance)", _instance];
            _code breakout "translateNode";
        };

    };

    ""
};

generateCode = {
    params ["_source"];

    _parser = [_source] call parserCreate;

    private _ast = _parser select 0;
    private _code = _ast call translateNode;
    code = _code;
    ""
};