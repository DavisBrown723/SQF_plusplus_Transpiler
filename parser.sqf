#define CURR_TOKEN          __token
#define STR_CURR_TOKEN      #CURR_TOKEN

#define ADVANCE()           _tokenPointer = _tokenPointer + 1;
#define REGRESS()           _tokenPointer = (_tokenPointer - 1) max 0;

#define CONSUME()           ADVANCE(); if (_tokenPointer < _tokenCount) then { CURR_TOKEN = _tokens select _tokenPointer } else { CURR_TOKEN = nil };
#define BACKTRACK()         REGRESS(); CURR_TOKEN = _tokens select _tokenPointer;



#define ERROR_NO_TOKEN(expected)        [composeText ["Expecting:   ", expected, linebreak, "Received:    end of source input"]] call sqfpp_fnc_parseError;
#define ERROR_WRONG_TOKEN(expected)     [composeText ["Expecting:   ", expected, linebreak, "Received:    ", CURR_TOKEN select 1]] call sqfpp_fnc_parseError;

#define ERROR_CURR_TOKEN(expected)      if (isnil STR_CURR_TOKEN) then { ERROR_NO_TOKEN(expected) } else { ERROR_WRONG_TOKEN(expected) };

#define ACCEPT_SYM(sym)                 (!isnil STR_CURR_TOKEN && {(CURR_TOKEN select 1) == sym})
#define ACCEPT_TYPE(type)               (!isnil STR_CURR_TOKEN && {(CURR_TOKEN select 0) == type})

#define EXPECT_SYM(sym)                 (if (ACCEPT_SYM(sym))  then {true} else { ERROR_CURR_TOKEN(sym) })
#define EXPECT_TYPE(type)               (if (ACCEPT_TYPE(type)) then {true} else { ERROR_CURR_TOKEN(type) })

#define ASSERT_DEF(var,msg)             if (isnil #var) then { [msg] call sqfpp_fnc_parseError };


// helper functions

sqfpp_fnc_parseError = {
    params ["_message","_parameters"];

    private _lastToken = if (isnil STR_CURR_TOKEN) then {
        (_tokens select (count _tokens - 1))
    } else {
        CURR_TOKEN
    };

    private _locationData = _lastToken select 2;
    _locationData params ["_line","_column"];

    private _fullMessage = composeText [_message, linebreak, "Line ", str _line];

    //private _errorData = [_fullMessage] + _messageParameters;
    //private _errorMessage = format _errorData;
    [_locationData,_allTokens,_fullMessage] call sqfpp_fnc_parserErrorUI;

    breakto "ast_generation";
};

sqfpp_fnc_parserErrorUI = {
    _this spawn {
        params ["_errorLocation","_tokens","_errorMessage"];

        disableSerialization;

        private _nextIDC = 72300;
        private _getNextIDC = {
            private _idc = _nextIDC;
            _nextIDC = _nextIDC + 1;
            _idc
        };

        private _display = (findDisplay 46) createDisplay "RscDisplayEmpty";

        private _backgroundPosition  = [safezoneX + safezoneW * 0.2, safezoneY + safezoneH * 0.2, safezoneW * 0.5, safezoneH * 0.45];
        private _background = _display ctrlCreate ["RscText", call _getNextIDC];
        _background ctrlsetposition _backgroundPosition;
        _background ctrlSetBackgroundColor [0, 0, 0, 1];
        _background ctrlcommit 0;

        // find last line number

        private _lastLineIndex = 0;
        {
            private _tokenLine = _x select 2 select 0;
            if (_tokenLine > _lastLineIndex) then {_lastLineIndex = _tokenLine};
        } foreach _tokens;

        // find lines nearby error

        _errorLocation params ["_errorLine","_errorColumn"];

        // number of lines of context to show around the error
        private _contextRange = 2;

        private _minLine = (_errorLine - _contextRange) max 1;
        private _maxLine = (_errorLine + _contextRange) min _lastLineIndex;

        private _leftLower = _contextRange - (_errorLine - _minLine);
        private _leftUpper = _contextRange - (_maxLine - _errorLine);

        // if space is left on one side
        // allocate it to the other side

        if (_leftUpper > 0 && _minLine > 1) then {
            _minLine = (_minLine - _leftUpper) max 1;
        };

        if (_leftLower > 0 && _leftUpper == 0) then {
            _maxLine = _maxLine + _leftLower;
        };

        private _contextLines = [[],[],[],[],[]];
        //private _typesToIgnore = ["end_line","end_of_file"];

        {
            private _token = _x;
            _token params ["_tokenType","_tokenContent","_tokenLocation"];
            _tokenLocation params ["_line","_column"];

            if (_line >= _minLine && _line <= _maxLine) then {
               //if !(_tokenType in _typesToIgnore) then {
                    private _contextLine = _line - _minLine;
                    (_contextLines select _contextLine) pushback [_tokenContent,_column];
                //};
            };
        } foreach _tokens;

        private _filledContextLines = _contextLines select { count _x > 0};

        private _lineX = (_backgroundPosition select 0) + (_backgroundPosition select 2) * 0.10;
        private _lineY = (_backgroundPosition select 1) + (_backgroundPosition select 3) * 0.10;
        private _lineWidth = (_backgroundPosition select 2) * 0.80;
        private _lineHeight = (_backgroundPosition select 3) * 0.10;

        {
            private _tokensInLine = _x;
            private _hasText = count _tokensInLine > 0;

            if (_hasText) then {
                // create text line control

                private _textCtrl = _display ctrlCreate ["RscText", call _getNextIDC];

                // green: lines before error
                // green: error line before error
                //  -> red: error line after error
                // yellow: lines following error line

                private _currLine = _minLine + _foreachindex;
                private _lineDiff = _errorLine - _currLine;

                private _calculateLineWidth = {
                    params ["_text"];

                    private _characters = _text splitstring "";
                    private _characterCount = count _characters;

                    private _widthPerCharacter = safezoneW * 0.00375;
                    private _lineWidth = _widthPerCharacter * _characterCount;

                    _lineWidth
                };

                switch (true) do {

                    // green
                    case (_lineDiff > 0):   {
                        private _lineText = "";
                        {
                            _lineText = _lineText + (_x select 0);
                        } foreach _tokensInLine;

                        _textCtrl ctrlsettext _lineText;
                        _textCtrl ctrlSetTextColor [0,1,0,1];
                        _textCtrl ctrlsettooltip "OK";

                        _textCtrl ctrlsetposition [_lineX, _lineY + (_lineHeight * _foreachindex), [_lineText] call _calculateLineWidth, _lineHeight];
                        _textCtrl ctrlcommit 0;
                    };

                    // green -> red
                    case (_lineDiff == 0):  {
                        private _lineTextBeforeError = "";
                        private _lineTextAfterError = "";
                        {
                            _x params ["_tokenContent","_tokenColumn"];

                            if (_tokenColumn < _errorColumn) then {
                                _lineTextBeforeError = _lineTextBeforeError + _tokenContent;
                            } else {
                                _lineTextAfterError = _lineTextAfterError + _tokenContent;
                            };
                        } foreach _tokensInLine;

                        _textCtrl ctrlsetposition [_lineX, _lineY + (_lineHeight * _foreachindex), [_lineTextBeforeError] call _calculateLineWidth, _lineHeight];
                        _textCtrl ctrlcommit 0;

                        _textCtrl ctrlsettext _lineTextBeforeError;
                        _textCtrl ctrlSetTextColor [0,1,0,1];
                        _textCtrl ctrlSetBackgroundColor [1,1,1,0.45];
                        _textCtrl ctrlsettooltip "OK";

                        // create red line control

                        private _validLinePosition = ctrlposition _textCtrl;
                        private _endValidLine = (_validLinePosition select 0) + (_validLinePosition select 2);

                        private _errorTextCtrl = _display ctrlCreate ["RscText", call _getNextIDC];
                        _errorTextCtrl ctrlsettext _lineTextAfterError;
                        _errorTextCtrl ctrlsetposition [_endValidLine, _lineY + (_lineHeight * _foreachindex), [_lineTextAfterError] call _calculateLineWidth, _lineHeight];
                        _errorTextCtrl ctrlSetTextColor [1, 0, 0, 1];
                        _errorTextCtrl ctrlSetBackgroundColor [1,1,1,0.45];
                        _errorTextCtrl ctrlsettooltip "ERROR";
                        _errorTextCtrl ctrlcommit 0;
                    };

                    // yellow
                    case (_lineDiff < 0): {
                        private _lineText = "";
                        {
                            _lineText = _lineText + (_x select 0);
                        } foreach _tokensInLine;

                        _textCtrl ctrlsetposition [_lineX, _lineY + (_lineHeight * _foreachindex), [_lineText] call _calculateLineWidth, _lineHeight];
                        _textCtrl ctrlcommit 0;

                        _textCtrl ctrlsettext _lineText;
                        _textCtrl ctrlSetTextColor [0.741,0.706,0.216,1];
                        _textCtrl ctrlsettooltip "UNCHECKED";
                    };

                };
            };
        } foreach _contextLines;

        // display error message below context
        private _error = _display ctrlCreate ["RscStructuredText", call _getNextIDC];
        _error ctrlsetposition [_lineX, _lineY + (_lineHeight * (count _filledContextLines + 1)), _lineWidth, _lineHeight * 3];
        _error ctrlsetstructuredtext  _errorMessage;
        _error ctrlcommit 0;
    };
};


// Wishlist
// subscript operator : array[0][2];
// continue statement
//  - invert containing condition
//  - wrap parenting for/while body in true-block



// Define Node Classes



sqfpp_fnc_createNode = {
    params ["_type","_properties"];

    switch (_type) do {
        case "identifier": {
            _properties params ["_identifierToken"];

            [_type, _identifierToken select 1]
        };
        case "namespace_accessor": {
            _properties params ["_operator","_left","_right"];

            private _typeLeft = _left select 0;
            private _typeRight = _right select 0;

            if !(_typeLeft in ["identifier","namespace_accessor"]) then { ["Namespace accessor left argument must be identifier"] call sqfpp_fnc_parseError; };
            if !(_typeRight in ["identifier","function_call","namespace_accessor"]) then { ["Namespace accessor right argument must be identifier or function call"] call sqfpp_fnc_parseError; };

            [_type,_left,_right]
        };
        case "if": {
            _properties params ["_condition","_trueBlock","_falseBlock"];

            [_type,_condition,_trueBlock,_falseBlock]
        };
        case "while": {
            _properties params ["_condition","_block",["_needsScopeWrap", false]];

            [_type,_condition,_block,_needsScopeWrap]
        };
        case "for": {
            _properties params ["_pre","_condition","_post","_block",["_needsScopeWrap", false]];

            [_type,_pre,_condition,_post,_block,_needsScopeWrap]
        };
        case "foreach": {
            _properties params ["_list","_enumerationVar","_block",["_needsScopeWrap", false]];

            [_type,_list,_enumerationVar,_block,_needsScopeWrap]
        };
        case "switch": {
            _properties params ["_condition","_cases",["_needsScopeWrap", false]];

            [_type,_condition,_cases,_needsScopeWrap]
        };
        case "block": {
            _properties params [["_statementList",[]]];

            [_type, _statementList];
        };
        case "variable_definition": {
            _properties params ["_varIdentifierToken"];

            private _varIdentifierNode = ["identifier", [_varIdentifierToken]] call sqfpp_fnc_createNode;

            [_type, _varIdentifierNode]
        };
        case "assignment": {
            _properties params ["_operator","_left","_right"];

            [_type,_left,_operator,_right]
        };
        case "literal": {
            _properties params ["_literalToken"];

            [_type, _literalToken select [0,2]]
        };
        case "unary_operation": {
            _properties params ["_operator","_right"];

            [_type,_operator,_right]
        };
        case "new_instance": {
            _properties params ["_functionCallNode"];

            private _class = _functionCallNode select 1;
            private _arguments = _functionCallNode select 2;

            [_type,_class,_arguments]
        };
        case "delete_instance": {
            _properties params ["_expression"];

            [_type,_expression]
        };
        case "copy_variable": {
            _properties params ["_expression"];

            [_type,_expression]
        };
        case "init_parent_class": {
            _properties params ["_functionCallNode"];

            private _class = _functionCallNode select 1;
            private _arguments = _functionCallNode select 2;

            // create token from class name
            // #todo: function_Call should use token for name
            _class = ["identifier", [ ["identifier", _class] ]] call sqfpp_fnc_createNode;

            [_type,_class,_arguments]
        };
        case "binary_operation": {
            _properties params ["_operator","_left","_right"];

            [_type,_operator,_left,_right]
        };
        case "function_call": {
            _properties params ["_function","_arguments"];

            [_type, _function, _arguments]
        };
        case "method_call": {
            _properties params ["_object","_method","_arguments"];

            [_type, _object, _method, _arguments]
        };
        case "class_access": {
            _properties params ["_symbol","_object","_member"];

            private _memberNodeType = _member select 0;
            if (_memberNodeType == "function_call") exitwith {
                private _methodName = _member select 1;
                private _methodArgs = _member select 2;

                ["method_call", [_object, _methodName, _methodArgs]] call sqfpp_fnc_createNode;
            };

            [_type, _object, _member]
        };
        case "lambda": {
            _properties params ["_parameterList","_body"];

            [_type, _parameterList, _body]
        };
        case "raw_sqf": {
            _properties params ["_tokens"];

            [_type, _tokens]
        };
        case "function_parameter": {
            _properties params ["_validTypes","_varName","_defaultValue"];

            [_type, _validTypes, _varName, _defaultValue]
        };
        case "named_function": {
            _properties params ["_identifier","_parameterList","_body"];

            [_type,_identifier,_parameterList,_body]
        };
        case "class_definition": {
            _properties params ["_classname","_parents","_varNodes","_funcNodes"];

            [_type,_classname,_parents,_varNodes,_funcNodes]
        };
        case "return": {
            _properties params ["_expression"];

            [_type,_expression]
        };
        case "unnamed_scope": {
            _properties params ["_block",["_forceUnscheduled",false]];

            [_type,_block,_forceUnscheduled]
        };
        case "break": {
            ["break"]
        };
        case "continue": {
            ["continue"]
        };
        case "empty_statement": {
            [_type]
        };
        case "namespace_block": {
            _properties params ["_name","_block"];

            private _blockNodes = _block select 1;

            [_type,_name,_blockNodes]
        };
        default {
            ["Parser","Unkown Node Type Requested: %1", [_type]] call sqfpp_fnc_error;
        };
    };
};

methodInstanceParameter = ["function_parameter", [[],"__sqfpp_this","sqfpp_defValue"]] call sqfpp_fnc_createNode;



sqfpp_fnc_parse = {
    private _source = _this;

    private _allTokens = _source call sqfpp_fnc_lex;

    // generate AST

    private _tokenCount = count _allTokens;
    private _tokenPointer = -1; // will be incremented by first CONSUME() call

    private _parsingContext = "";
    private _astNodes = [];

    private _ast = ["block", [_astNodes]] call sqfpp_fnc_createNode;

    if (_tokenCount > 0) then {

        scopename "ast_generation";

        private _whitespaceTypes = ["whitespace","end_line"];

        // maybe remove whitespace tokens from array
        // and splice them into the output array??

        private _tokens = _allTokens select { !((_x select 0) in _whitespaceTypes) };
        _tokenCount = count _tokens;

        private STR_CURR_TOKEN;
        CONSUME();
        while {_tokenPointer < _tokenCount} do {
            private _node = [] call sqfpp_fnc_parseStatement;
            _astNodes pushback _node;
        };

        // transformations

        _ast call sqfpp_fnc_transformNamespaceAccess;
        _ast call sqfpp_fnc_checkTreeValidity;

        _ast call sqfpp_fnc_precompileClasses;

        _ast call sqfpp_fnc_transformContinuedLoops;
        _ast call sqfpp_fnc_transformClassMemberAccess;
        _ast call sqfpp_fnc_transformClassSelfReferences;

    };

    _ast
};



// Parse Methods



sqfpp_fnc_parseNamespaceSpecifier = {
    scopename "parseNamespaceSpecifier";

    if (ACCEPT_SYM("namespace")) then {
        CONSUME();

        if (EXPECT_TYPE("identifier")) then {
            private _namespace = CURR_TOKEN select 1;
            CONSUME();

            private _block = call sqfpp_fnc_parseBlock;

            // verify block contains only valid node types

            private _blockNodes = _block select 1;
            {
                private _nodeType = _x select 0;

                private _valid = false;
                switch (_nodeType) do {
                    case "namespace_block";
                    case "named_function";
                    case "class_definition": { _valid = true };
                    case "expression_statement": {
                        private _leftNode = _x select 1;
                        private _leftNodeType = _leftNode select 0;

                        if (_leftNodeType == "assignment") then {
                            _valid = true;
                        };
                    };
                };

                if (!_valid) then {
                    [format ["Namespace block '%1' may only contain global variable definitions, named function definitions, or class definitions", _namespace]] call sqfpp_fnc_parseError;
                };
            } foreach _blockNodes;

            private _namespaceNode = ["namespace_block", [_namespace,_block]] call sqfpp_fnc_createNode;
            _namespaceNode breakout "parseNamespaceSpecifier";
        };
    };
};


sqfpp_fnc_parseNularStatements = {
    scopename "parseNularStatements";

    if (ACCEPT_TYPE("nular")) then {
        private _nularKeyword = CURR_TOKEN select 1;
        CONSUME();

        if (EXPECT_TYPE("semicolon")) then {
            CONSUME();

            private _nularNode = [_nularKeyword] call sqfpp_fnc_createNode;
            _nularNode breakout "parseNularStatements";
        };
    };
};


sqfpp_fnc_parseUnaryStatements = {
    scopename "parseUnaryStatements";

    if (ACCEPT_TYPE("unary")) then {
        private _unaryKeyword = CURR_TOKEN select 1;

        switch (_unaryKeyword) do {
            case "return": {
                CONSUME();

                // check for empty return statement

                if (ACCEPT_TYPE("semicolon")) then {
                    CONSUME();

                    private _unaryNode = ["return", [[]]] call sqfpp_fnc_createNode;
                    _unaryNode breakout "parseUnaryStatements";
                };

                // return a value

                private _returnExpression = [] call sqfpp_fnc_parseExpression;

                if (EXPECT_TYPE("semicolon")) then {
                    CONSUME();

                    private _unaryNode = ["return", [_returnExpression]] call sqfpp_fnc_createNode;
                    _unaryNode breakout "parseUnaryStatements";
                };
            };
        };
    };
};


sqfpp_fnc_parseIfStatement = {
    scopename "parseIfStatement";

    if (ACCEPT_SYM("if")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();
            private _conditionExpression = [] call sqfpp_fnc_parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                private _trueBlock = [];
                private _falseBlock = [];

                // parse true block

                if (ACCEPT_SYM("{")) then {
                    _trueBlock = call sqfpp_fnc_parseBlock;
                } else {
                    private _statement = [] call sqfpp_fnc_parseStatement;
                    _trueBlock = ["block", [[_statement]]] call sqfpp_fnc_createNode;
                };

                // parse false block

                if (ACCEPT_SYM("else")) then {
                    CONSUME();

                    if (ACCEPT_SYM("{")) then {
                        _falseBlock = call sqfpp_fnc_parseBlock;
                    } else {
                        // check for elseif

                        if (ACCEPT_SYM("if")) then {
                            // parse another if statement
                            // insert into false block

                            private _ifNode = call sqfpp_fnc_parseIfStatement;
                            _falseBlock = ["block", [[_ifNode]]] call sqfpp_fnc_createNode;
                        } else {
                            // parse single-statement for else block
                            private _statement = [] call sqfpp_fnc_parseStatement;
                            _falseBlock = ["block", [[_statement]]] call sqfpp_fnc_createNode;
                        };
                    };
                };

                private _node = ["if", [_conditionExpression,_trueBlock,_falseBLock]] call sqfpp_fnc_createNode;
                _node breakout "parseIfStatement";
            };
        };
    };
};


sqfpp_fnc_parseWhileStatement = {
    scopename "parseWhileStatement";

    if (ACCEPT_SYM("while")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();
            private _conditionExpression = [] call sqfpp_fnc_parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                private _iterationBlock = [];

                if (ACCEPT_SYM("{")) then {
                    _iterationBlock = call sqfpp_fnc_parseBlock;
                } else {
                    private _statement = [] call sqfpp_fnc_parseStatement;
                    _iterationBlock = ["block", [[_statement]]] call sqfpp_fnc_createNode;
                };

                private _node = ["while", [_conditionExpression,_iterationBlock]] call sqfpp_fnc_createNode;
                _node breakout "parseWhileStatement";
            };
        };
    };
};


sqfpp_fnc_parseForStatement = {
    scopename "parseForStatement";

    if (ACCEPT_SYM("for")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();

            // peek ahead to see which type of for-loop we have
            // for(;;;)
            // for(var _e : _list)

            CONSUME();
            CONSUME();

            if (!ACCEPT_SYM(":")) then {
                // for-loop
                BACKTRACK();
                BACKTRACK();

                private _preStatement = [] call sqfpp_fnc_parseStatement;

                private _conditionStatement = [] call sqfpp_fnc_parseExpression;
                ASSERT_DEF(_conditionStatement,"For-loop missing valid conditional expression");
                CONSUME(); // remove ending semicolon

                private _postStatement = [true] call sqfpp_fnc_parseStatement;

                if (EXPECT_SYM(")")) then {
                    CONSUME();

                    private _iterationBlock = [];

                    if (ACCEPT_SYM("{")) then {
                        _iterationBlock = call sqfpp_fnc_parseBlock;
                    } else {
                        private _statement = [] call sqfpp_fnc_parseStatement;
                        _iterationBlock = ["block", [[_statement]]] call sqfpp_fnc_createNode;
                    };

                    private _node = ["for", [_preStatement,_conditionStatement,_postStatement,_iterationBlock]] call sqfpp_fnc_createNode;
                    _node breakout "parseForStatement";
                };
            } else {
                // foreach
                BACKTRACK();
                BACKTRACK();

                if (EXPECT_SYM("var")) then {
                    CONSUME();

                    if (EXPECT_TYPE("identifier")) then {
                        private _enumerationVar = ["identifier", [CURR_TOKEN]] call sqfpp_fnc_createNode;
                        CONSUME();

                        if (EXPECT_SYM(":")) then {
                            CONSUME();

                            private _list = [] call sqfpp_fnc_parseExpression;

                            if (EXPECT_SYM(")")) then {
                                CONSUME();

                                private _iterationBlock = [];

                                if (ACCEPT_SYM("{")) then {
                                    _iterationBlock = call sqfpp_fnc_parseBlock;
                                } else {
                                    private _statement = [] call sqfpp_fnc_parseStatement;
                                    _iterationBlock = ["block", [[_statement]]] call sqfpp_fnc_createNode;
                                };

                                private _node = ["foreach", [_list,_enumerationVar,_iterationBlock]] call sqfpp_fnc_createNode;
                                _node breakout "parseForStatement";
                            };
                        };

                    };
                };
            };

        };
    };
};


sqfpp_fnc_parseSwitchStatement = {
    scopename "parseSwitchStatement";

    if (ACCEPT_SYM("switch")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();

            private _switchCondition = [] call sqfpp_fnc_parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                if (EXPECT_SYM("{")) then {
                    CONSUME();

                    private _cases = [];

                    while {ACCEPT_SYM("case") || {ACCEPT_SYM("default")}} do {
                        private _caseCondition = [];

                        if (ACCEPT_SYM("case")) then {
                            _caseCondition = [] call sqfpp_fnc_parseExpression;
                        };
                        CONSUME();

                        if (EXPECT_SYM(":")) then {
                            CONSUME();

                            private _caseBlock = call sqfpp_fnc_parseBlock;
                            _cases pushback [_caseCondition,_caseBlock];
                        };
                    };

                    if (EXPECT_SYM("}")) then {
                        CONSUME();

                        private _switchNode = ["switch", [_switchCondition,_cases]] call sqfpp_fnc_createNode;
                        _switchNode breakout "parseSwitchStatement";
                    };
                };
            };
        };
    };
};


sqfpp_fnc_parseNamedFunctionDefinition = {
    scopename "parseNamedFunctionDefinition";

    if (ACCEPT_SYM("function")) then {
        CONSUME();

        if (ACCEPT_TYPE("identifier")) then {
            private _identifier = CURR_TOKEN select 1;
            CONSUME();

            private _parameterList = call sqfpp_fnc_parseFunctionParameters;
            private _body = call sqfpp_fnc_parseBlock;

            private _functionNode = ["named_function", [_identifier,_parameterList,_body]] call sqfpp_fnc_createNode;
            _functionNode breakout "parseNamedFunctionDefinition";
        } else {
            ["Function definition missing name"] call sqfpp_fnc_parseError;
        };
    };
};


sqfpp_fnc_parseClassDefinition = {
    scopename "parseClassDefinition";

    if (ACCEPT_SYM("class")) then {
        CONSUME();

        if (ACCEPT_TYPE("identifier")) then {
            private _classname = CURR_TOKEN select 1;
            CONSUME();

            // parse parent classes

            private _parentClassnames = [];

            if (ACCEPT_SYM(":")) then {
                CONSUME();

                private _parentsLeft = true;
                while {_parentsLeft} do {
                    _parentsLeft = false;

                    if (ACCEPT_TYPE("identifier")) then {
                        private _classname = CURR_TOKEN select 1;
                        _parentClassnames pushback _classname;

                        CONSUME();
                    } else {
                        [format ["Trailing comma in parent list for class %1", _classname]] call sqfpp_fnc_parseError;
                    };

                    if (ACCEPT_TYPE("comma")) then {
                        CONSUME();
                        _parentsLeft = true;
                    };
                };
            };

            if (EXPECT_SYM("{")) then {
                CONSUME();

                // parse class defining block

                private _vars = [];
                private _funcs = [];

                while {!ACCEPT_SYM("}")} do {
                    scopename "classDefinitionParseLoop";

                    call {
                        // parse member variable definition
                        // roll a custom solution here because
                        // we have strict requirements
                        if (ACCEPT_SYM("var")) then {
                            CONSUME();

                            if (EXPECT_TYPE("identifier")) then {
                                private _identifier = CURR_TOKEN select 1;
                                CONSUME();

                                // check for default value
                                if (EXPECT_SYM("=")) then {
                                    CONSUME();
                                    private _value = [] call sqfpp_fnc_parseExpression;

                                    if (ACCEPT_TYPE("semicolon")) then {
                                        CONSUME();

                                        _vars pushback [_identifier,_value];
                                        breakto "classDefinitionParseLoop";
                                    };
                                };
                            };
                        };

                        private _functionNode = call sqfpp_fnc_parseNamedFunctionDefinition;
                        if (!isnil "_functionNode") then {
                            // inject instance object as the first parameter
                            private _functionParameters = _functionNode select 2;
                            private _methodParameters = [+methodInstanceParameter] + _functionParameters;

                            private _functionName = _functionNode select 1;
                            private _functionBody = _functionNode select 3;
                            _funcs pushback [_functionName, _methodParameters, _functionBody];
                            breakto "classDefinitionParseLoop";
                        };

                        // neither case found
                        [format ["Invalid code inside class %1 definition", _classname]] call sqfpp_fnc_parseError;
                    };
                };

                CONSUME();

                // verify that special functions have appropriate parameter lists

                {
                    _x params ["_functionName","_functionParameters"];

                    switch (_functionName) do {
                        case "constructor": {
                            // we should have only one parameter
                            private _multipleParameters = (count _functionParameters) > 1;

                            if (_multipleParameters) then {
                                [format ["Class %1 definition constructor has too many arguments", _classname]] call sqfpp_fnc_parseError;
                            };
                        };
                        case "destructor": {
                            // we should have only one parameter
                            private _multipleParameters = (count _functionParameters) > 1;

                            if (_multipleParameters) then {
                                [format ["Class %1 definition destructor has too many arguments", _classname]] call sqfpp_fnc_parseError;
                            };
                        };
                        case "copy_constructor": {
                            // we should have only one parameter - of type Class
                            private _parameterCount = count _functionParameters;

                            if (_parameterCount == 1) then {
                                [format ["Class %1 copy_constructor definition has no arguments: expecting Class parameter", _classname]] call sqfpp_fnc_parseError;
                            };
                            if (_parameterCount > 2) then {
                                [format ["Class %1 copy_constructor definition has too many arguments", _classname]] call sqfpp_fnc_parseError;
                            };

                            private _firstParameter = _functionParameters select 1;
                            private _firstParameterTypes = _firstParameter select 1;

                            if !(_firstParameterTypes isequalto ["Class"]) then {
                                [format ["Class %1 copy_constructor definition has improper parameter types %2 : expecting Class", _classname, _firstParameterTypes]] call sqfpp_fnc_parseError;
                            };
                        };
                    };
                } foreach _funcs;

                private _classNode = ["class_definition", [_classname,_parentClassnames,_vars,_funcs]] call sqfpp_fnc_createNode;

                _classNode breakout "parseClassDefinition";
            };
        };
    };
};


sqfpp_fnc_parseUnnamedBlock = {
    scopename "parseUnnamedBlock";

    private _forceUnscheduled = false;
    if (ACCEPT_SYM("unscheduled")) then {
        CONSUME();

        _forceUnscheduled = true;
    };

    private _blockNode = call sqfpp_fnc_parseBlock;
    if (!isnil "_blockNode") then {
        ["unnamed_scope", [_blockNode,_forceUnscheduled]] call sqfpp_fnc_createNode;
    } else {
        if (_forceUnscheduled) then { BACKTRACK() };
    };

};


sqfpp_fnc_parseLiteral = {
    scopename "parseLiteral";

    if (ACCEPT_TYPE("number_literal")) then {
        private _literalNode = ["literal", [CURR_TOKEN]] call sqfpp_fnc_createNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("string_literal")) then {
        private _literalNode = ["literal", [CURR_TOKEN]] call sqfpp_fnc_createNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("bool_literal")) then {
        private _literalNode = ["literal", [CURR_TOKEN]] call sqfpp_fnc_createNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    // parse array literal

    if (ACCEPT_SYM("[")) then {
        CONSUME();

        // first, create array literal token
        // then create literal node

        if (ACCEPT_SYM("]")) then {
            CONSUME();

            private _arrayLiteralToken = ["array_literal", []];
            private _literalNode = ["literal", [_arrayLiteralToken]] call sqfpp_fnc_createNode;
            _literalNode breakout "parseLiteral";
        };

        // we have elements

        private _argExpressions = [];
        private _argsLeft = true;

        while {_argsLeft} do {
            _argsLeft = false;

            if (ACCEPT_SYM("]")) then {
                ["Trailing comma in array literal"] call sqfpp_fnc_parseError;
            };

            private _expressionNode = [] call sqfpp_fnc_parseExpression;
            _argExpressions pushback _expressionNode;

            if (ACCEPT_TYPE("comma")) then {
                CONSUME();
                _argsLeft = true;
            };
        };

        if (EXPECT_SYM("]")) then {
            CONSUME();

            private _arrayLiteralToken = ["array_literal", _argExpressions];
            private _literalNode = ["literal", [_arrayLiteralToken]] call sqfpp_fnc_createNode;
            _literalNode breakout "parseLiteral";
        };
    };
};


sqfpp_fnc_parseFunctionCall = {
    scopename "parseFunctionCall";

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        CONSUME();

        if (ACCEPT_SYM("(")) then {
            CONSUME();

            // we found a function call
            // parse arguments

            private _argExpressions = [];

            if (!ACCEPT_SYM(")")) then {
                private _argsLeft = true;

                while {_argsLeft} do {
                    _argsLeft = false;

                    if (ACCEPT_SYM(")")) then {
                        [format ["Trailing comma in argument list for function call %1", _identifier]] call sqfpp_fnc_parseError;
                    };

                    private _expressionNode = [] call sqfpp_fnc_parseExpression;
                    _argExpressions pushback _expressionNode;

                    if (ACCEPT_TYPE("comma")) then {
                        CONSUME();
                        _argsLeft = true;
                    };
                };
            };

            if (EXPECT_SYM(")")) then {
                CONSUME();
            };

            private _node = ["function_call", [_identifier,_argExpressions]] call sqfpp_fnc_createNode;
            _node breakout "parseFunctionCall";
        } else {
            BACKTRACK();
            breakout "parseFunctionCall"
        };
    };
};


sqfpp_fnc_parseLambda = {
    scopename "parseLambda";

    if (ACCEPT_SYM("function")) then {
        CONSUME();

        private _parameterList = call sqfpp_fnc_parseFunctionParameters;
        ASSERT_DEF(_parameterList,"lambda function must have an argument list");

        private _body = call sqfpp_fnc_parseBlock;
        ASSERT_DEF(_body,"lambda function must have a body");

        private _node = ["lambda", [_parameterList,_body]] call sqfpp_fnc_createNode;
        _node breakout "parseLambda";
    };
};


sqfpp_fnc_parseUnaryOperation = {
    scopename "parseUnaryOperation";

    if (ACCEPT_TYPE("operator")) then {
        private _operator = CURR_TOKEN select 1;
        private _operatorInfo = _operator call sqfpp_fnc_getOperatorInfo;
        private _operatorAttributes = _operatorInfo select 3;

        if ("unary" in _operatorAttributes) then {
            CONSUME();

            switch (_operator) do {
                case "new": {
                    private _functionCallNode = [] call sqfpp_fnc_parseFunctionCall;
                    ASSERT_DEF(_functionCallNode,"Invalid use of new");

                    private _node = ["new_instance", [_functionCallNode]] call sqfpp_fnc_createNode;
                    _node breakout "parseUnaryOperation";
                };
                case "delete": {
                    private _expression = [] call sqfpp_fnc_parseExpression;
                    ASSERT_DEF(_expression,"delete: expected an expression");

                    private _node = ["delete_instance", [_expression]] call sqfpp_fnc_createNode;
                    _node breakout "parseUnaryOperation";
                };
                case "copy": {
                    private _expression = [] call sqfpp_fnc_parseExpression;
                    ASSERT_DEF(_expression,"copy: expected an expression");

                    private _node = ["copy_variable", [_expression]] call sqfpp_fnc_createNode;
                    _node breakout "parseUnaryOperation";
                };
                case "init_super": {
                    private _expression = [] call sqfpp_fnc_parseExpression;
                    ASSERT_DEF(_expression,"init_super: expected an expression");

                    private _node = ["init_parent_class", [_expression]] call sqfpp_fnc_createNode;
                    _node breakout "parseUnaryOperation";
                };
                default {
                    private _expressionNode = [] call sqfpp_fnc_parseExpression;
                    if (isnil "_expressionNode") then { [format ["Unary Operator %1 is not applied to a valid expression", _operator]] call sqfpp_fnc_parseError };

                    private _node = ["unary_operation", [_operator,_expressionNode]] call sqfpp_fnc_createNode;
                    _node breakout "parseUnaryOperation";
                };
            };
        };
    };
};


sqfpp_fnc_parseIdentifier = {
    scopename "parseIdentifier";

    if (ACCEPT_SYM("var")) then {
        CONSUME();

        if (EXPECT_TYPE("identifier")) then {
            private _identifierToken = CURR_TOKEN;
            CONSUME();

            private _node = ["variable_definition", [_identifierToken]] call sqfpp_fnc_createNode;
            _node breakout "parseIdentifier";
        };
    };

    if (ACCEPT_TYPE("identifier")) then {
        private _node = ["identifier", [CURR_TOKEN]] call sqfpp_fnc_createNode;
        CONSUME();
        _node breakout "parseIdentifier";
    };
};


sqfpp_fnc_parseAtom = {
    scopename "parseAtom";

    private "_node";

    // handle expressions nested in parenthesis
    if (ACCEPT_SYM("(")) then {
        CONSUME();
        _node = [] call sqfpp_fnc_parseExpression;

        if (EXPECT_SYM(")")) then {
            CONSUME();
            _node breakout "parseAtom";
        };
    };

    _node = call sqfpp_fnc_parseLiteral;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseLambda;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseFunctionCall;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseUnaryOperation;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseIdentifier;
    if (!isnil "_node") exitwith {_node};

    if (isnil STR_CURR_TOKEN) then { ["Unexpected end of input"] call sqfpp_fnc_parseError };

    [format ["Parse Atom could find relevant token - %1", CURR_TOKEN]] call sqfpp_fnc_parseError;
};


// Use precedence climbing to enforce operator precedence and associativity
// https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing/

sqfpp_fnc_parseExpression = {
    params [["_minPrecedence", 1]];

    private _atomLHS = call sqfpp_fnc_parseAtom;

    // handle binary operators

    while {true} do {
        if (isnil STR_CURR_TOKEN) exitwith { ERROR_NO_TOKEN("") };

        private _currSymbol = CURR_TOKEN select 1;
        private _operatorInfo = _currSymbol call sqfpp_fnc_getOperatorInfo;

        // not an operator
        if (isnil "_operatorInfo") exitwith {};

        _operatorInfo params ["_opSymbol","_opPrecedence","_opAssociativity","_opAttributes"];

        // if current operator precedence is greater than last operator's
        // create new expression as right-hand value

        if (!("binary" in _opAttributes) || { _opPrecedence < _minPrecedence }) exitwith {};

        private _nextMinPrecedence = _opPrecedence;
        if (_opAssociativity == "left") then {
            _nextMinPrecedence = _opPrecedence + 1;
        };

        CONSUME();
        private _atomRHS = [_nextMinPrecedence] call sqfpp_fnc_parseExpression;

        private _nodeType = _currSymbol call sqfpp_fnc_getTokenNodeType;
        if (isnil "_nodeType") then {_nodeType = "binary_operation"};

        // collapse result into single expression
        _atomLHS = [_nodeType, [_currSymbol,_atomLHS,_atomRHS]] call sqfpp_fnc_createNode;
    };

    _atomLHS
};


sqfpp_fnc_parseBlock = {
    scopename "parseBlock";

    // parse standard block

    if (ACCEPT_SYM("{")) then {
        CONSUME();

        private _statements = [];

        while {!ACCEPT_SYM("}")} do {
            private _statement = [] call sqfpp_fnc_parseStatement;
            _statements pushback _statement;
        };

        CONSUME();

        private _node = ["block", [_statements]] call sqfpp_fnc_createNode;
        _node breakout "parseBlock";
    };

    // parse raw sqf block

    private _rawSQF = false;
    if (ACCEPT_SYM("sqf")) then {
        _rawSQF = true;
        CONSUME();

        // grab all tokens except
        // opening and closing braces

        if (ACCEPT_SYM("{")) then {
            CONSUME();

            private _sqfTokens = [];
            private _depth = 1;

            while {_depth > 0} do {
                private _currSymbol = CURR_TOKEN select 1;

                switch (_currSymbol) do {
                    case "{": {
                        _depth = _depth + 1;
                        _sqfTokens pushback CURR_TOKEN;
                    };
                    case "}": {
                        _depth = _depth - 1;

                        if (_depth > 0) then {
                            _sqfTokens pushback CURR_TOKEN;
                        };
                    };
                    default {
                        _sqfTokens pushback CURR_TOKEN;
                    };
                };

                CONSUME();
            };

            private _node = ["raw_sqf", [_sqfTokens]] call sqfpp_fnc_createNode;
            _node breakout "parseBlock";
        } else {
            BACKTRACK();
            nil breakout "parseBlock";
        };
    };
};

sqfpp_fnc_parseFunctionParameters = {
    private _parameterList = [];

    if (EXPECT_SYM("(")) then {
        CONSUME();

        while {!ACCEPT_SYM(")")} do {

            // parse valid types for parameter

            EXPECT_TYPE("identifier");
            private _identifier = CURR_TOKEN select 1;
            CONSUME();

            // splitString does not support whole-word delimiters
            private _parameterTypes = [_identifier, "_or_", true] call BIS_fnc_splitstring;
            {
                private _parameterType = _x;
                private _isValidType = _parameterType call sqfpp_fnc_isValidType;

                if (!_isValidType) then {
                    [format ["Invalid parameter type: %1", _parameterType]] call sqfpp_fnc_parseError;
                };
            } foreach _parameterTypes;

            // parse parameter name

            EXPECT_TYPE("identifier");
            private _parameterName = CURR_TOKEN select 1;
            CONSUME();

            // parse optional default value

            private _defaultValue = "sqfpp_defValue";
            if (ACCEPT_SYM("=")) then {
                CONSUME();

                _defaultvalue = [] call sqfpp_fnc_parseExpression;
            };

            // remove comma, prep for next parameter
            // this allows for trailing commas but w/e
            if (ACCEPT_TYPE("comma")) then {
                CONSUME();
            };

            private _parameterNode = ["function_parameter", [_parameterTypes,_parameterName,_defaultvalue]] call sqfpp_fnc_createNode;
            _parameterList pushback _parameterNode;

        };

        // consume closing parenthesis
        CONSUME();
    };

    _parameterList
};


sqfpp_fnc_parseStatement = {
    params [["_omitSemicolon", false]];

    if (ACCEPT_TYPE("semicolon")) exitwith {
        CONSUME();

        ["empty_statement"] call sqfpp_fnc_createNode
    };

    private "_node";

    _node = call sqfpp_fnc_parseNamespaceSpecifier;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseNularStatements;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseUnaryStatements;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseIfStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseWhileStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseForStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseSwitchStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseNamedFunctionDefinition;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseClassDefinition;
    if (!isnil "_node") exitwith {_node};

    _node = call sqfpp_fnc_parseUnnamedBlock;
    if (!isnil "_node") exitwith {_node};

    _node = [] call sqfpp_fnc_parseExpression;
    if (!isnil "_node") exitwith {
        if (!_omitSemicolon) then {
            EXPECT_TYPE("semicolon");
            CONSUME();
        };

        // change this node's type so we
        // can easily add semicolons
        // during code generation
        ["expression_statement", _node]
    };

    ["Unrecognized token while parsing statement %1", [CURR_TOKEN]] call sqfpp_fnc_parseError;
};