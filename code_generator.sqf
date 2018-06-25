translateNode = {
    private _node = _this;

    scopename "translateNode";
systemchat format ["Node: %1", _node];
    switch (_node select 0) do {

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

            systemchat format ["Token: %1 \n\n Literal: %2", _token, _literal];

            //if ((_token select 0) == "array_literal") then {
            //    //private _code = _literal;
            //    //_code breakout "translateNode";
            //};

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
                _code = _code + (format ["%1 %2 %3;", _left call translateNode, _operator, _right call translateNode]);
            };

            _code breakout "translateNode";
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

            private _code = format ["if (%1) then {%2}", _condition call translateNode, _trueBlock call translateNode];

            if !(_falseBlock isequalto []) then {
                _code = _code + format [" else {%1}", _falseBlock call translateNode];
            };
        };

        case "while": {
            private _condition = _node select 1;
            private _block = _node select 2;=

            private _code = format ["while (%1) do {%2}", _condition call translateNode, _block call translateNode];
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