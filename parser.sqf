// recursive descent parser with backtracking

#define CURR_TOKEN          __token

#define ADVANCE()           _tokenPointer = _tokenPointer + 1;
#define REGRESS()           _tokenPointer = (_tokenPointer - 1) max 0;

#define TOKENS_LEFT()       (_tokenPointer < _tokenCount - 1)

#define CONSUME()           ADVANCE(); if (_tokenPointer < _tokenCount) then {CURR_TOKEN = _tokens select _tokenPointer} else {CURR_TOKEN = nil};
#define BACKTRACK()         REGRESS(); CURR_TOKEN = _tokens select _tokenPointer;

#define ACCEPT_SYM(char)    (!isnil "__token" && {(CURR_TOKEN select 1) == char})
#define ACCEPT_TYPE(char)   (!isnil "__token" && {(CURR_TOKEN select 0) == char})

#define EXPECT_SYM(char)    (if (ACCEPT_SYM(char))  then {true} else { hint parsetext format ["<t size='1.6'> ERROR: Expecting   %1" + endl + "Received   %2" + endl + "Line   %3</t>", char, CURR_TOKEN select 1, CURR_TOKEN select 2]; breakto "ast_generation"})
#define EXPECT_TYPE(char)   (if (ACCEPT_TYPE(char)) then {true} else { hint parsetext format ["<t size='1.6'> ERROR: Expecting   %1" + endl + "Received   %2" + endl + "Line   %3</t>", char, CURR_TOKEN select 1, CURR_TOKEN select 2]; breakto "ast_generation"})

// Wishlist
// subscript operator : array[0][2];
// continue statement
//  - invert containing condition
//  - wrap parenting for/while body in true-block

// Refactor priorities
// we use way too much breakto/breakout right now
// proper error handling and feedback

parserCreate = {
    params ["_source"];

    private _lexer = [_source] call lexerCreate;
    private _tokens = (_lexer select 1) select { !((_x select 0) in ["whitespace","end_line"]) };

    // generate AST

    private _tokenCount = count _tokens;
    private _tokenPointer = -1; // will be incremented by first CONSUME() call

    private _parsingContext = "";
    private _ast = [];

    if (_tokenCount > 0) then {

        scopename "ast_generation";

        private "__token";
        CONSUME();
        while {_tokenPointer < _tokenCount} do {
            _ast pushback (call parseStatement);
        };

    };

    _ast = [_ast] call BlockNode;

    [_ast]
};





// Define Node Classes

ITENode = {
    params ["_condition","_trueBlock","_falseBlock"];

    ["if",_condition,_trueBlock,_falseBlock]
};

WhileNode = {
    params ["_condition","_block"];

    ["while",_condition,_block]
};

ForNode = {
    params ["_pre","_condition","_post","_block"];

    ["for",_pre,_condition,_post,_block]
};

ForeachNode = {
    params ["_list","_enumerationVar","_block"];

    ["foreach",_list,_enumerationVar,_block]
};

SwitchNode = {
    params ["_condition","_cases"];

    ["switch",_condition,_cases]
};

BlockNode = {
    params [["_statementList",[]]];

    ["block", _statementList];
};

VariableDefinitionNode = {
    params ["_expression"];

    ["variable_definition", _expression]
};

assignmentNode = {
    params ["_left","_operator","_right"];

    ["assignment",_left,_operator,_right]
};

identifierNode = {
    params ["_identifierToken"];

    ["identifier", _identifierToken select [0,2]]
};

literalNode = {
    params ["_literalToken"];

    ["literal", _literalToken select [0,2]]
};

unaryOperationNode = {
    params ["_operator","_right"];

    ["unary",_operator,_right]
};

newInstanceNode = {
    params ["_class","_arguments"];

    ["new_instance",_class,_arguments]
};

deleteInstanceNode = {
    params ["_instance"];

    ["delete_instance",_instance]
};

nularStatementNode = {
    params ["_symbol"];

    ["nular_statement",_symbol]
};

UnaryStatementNode = {
    params ["_symbol","_right"];

    ["unary_statement",_symbol,_right]
};

binaryOperationNode = {
    params ["_operator","_left","_right"];

    ["binary",_operator,_left,_right]
};

functionCallNode = {
    params ["_function","_arguments"];

    ["function_call", _function, _arguments]
};

methodCallNode = {
    params ["_object","_method","_arguments"];

    ["method_call", _object, _method, _arguments]
};

classAccessNode = {
    params ["_object","_member"];

    ["class_access", _object, _member]
};

lambdaNode = {
    params ["_parameterList","_body"];

    ["lambda", _parameterList, _body]
};

rawSQFNode = {
    params ["_tokens"];

    ["raw_sqf", _tokens]
};

functionParameterNode = {
    params ["_validTypes","_varName","_defaultValue"];

    ["function_parameter", _validTypes, _varName, _defaultValue]
};
methodInstanceParameter = [[],"__sqfpp_this","sqfpp_defValue"] call functionParameterNode;

namedFunctionNode = {
    params ["_identifier","_parameterList","_body"];

    ["named_function",_identifier,_parameterList,_body]
};

classDefinitionNode = {
    params ["_classname","_parents","_varNodes","_funcNodes"];

    ["class_definition",_classname,_parents,_varNodes,_funcNodes]
};




// Parse Methods

parseIdentifier = {
    scopename "parseIdentifier";

    if (ACCEPT_TYPE("identifier")) then {
        private _identifierNode = [CURR_TOKEN] call identifierNode;
        CONSUME();
        _identifierNode breakout "parseIdentifier";
    };
};

parseLiteral = {
    scopename "parseLiteral";

    if (ACCEPT_TYPE("number_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("string_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("bool_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        CONSUME();
        _literalNode breakout "parseLiteral";
    };

    // parse array literal
    if (ACCEPT_SYM("[")) then {
        CONSUME();

        if (ACCEPT_SYM("]")) then {
            CONSUME();

            private _literalNode = [["array_literal", []]] call literalNode;
            _literalNode breakout "parseLiteral";
        };

        // we have elements

        private _argExpressions = [];
        private _argsLeft = true;

        while {_argsLeft} do {
            _argsLeft = false;

            if (ACCEPT_SYM("]")) then {
                hint "ERROR: Trailing comma";
                breakto "ast_generation";
            };

            private _expressionNode = [1] call parseExpression;
            _argExpressions pushback _expressionNode;

            if ((CURR_TOKEN select 1) == ",") then {
                CONSUME();
                _argsLeft = true;
            };
        };

        if (EXPECT_SYM("]")) then {
            CONSUME();

            private _literalNode = [["array_literal", _argExpressions]] call literalNode;
            _literalNode breakout "parseLiteral";
        };
    };
};

parseFunctionCall = {
    scopename "parseFunctionCall";

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        CONSUME();

        if (ACCEPT_SYM("(")) then {
            CONSUME();

            // confirmed function call

            private _argExpressions = [];

            // handle zero arg functions
            if (!ACCEPT_SYM(")")) then {
                private _argsLeft = true;

                while {_argsLeft} do {
                    _argsLeft = false;

                    if (ACCEPT_SYM(")")) then {
                        hint "ERROR: Trailing comma";
                        breakto "ast_generation";
                    };

                    private _expressionNode = [1] call parseExpression;
                    _argExpressions pushback _expressionNode;

                    //if (ACCEPT_SYM(",")) then {
                    if ((CURR_TOKEN select 1) == ",") then {
                        CONSUME();
                        _argsLeft = true;
                    };
                };
            };

            if (EXPECT_SYM(")")) then {
                CONSUME();
            } else {
                hint "ERROR: Missing )";
                breakto "ast_generation";
            };

            private _node = [_identifier,_argExpressions] call functionCallNode;
            _node breakout "parseFunctionCall";
        } else {
            BACKTRACK();
            breakout "parseFunctionCall"
        };
    };
};

parseLambda = {
    scopename "parseLambda";

    if (ACCEPT_TYPE("identifier") && { (CURR_TOKEN select 1) == "function"}) then {
        CONSUME();

        private _parameterList = call parseFunctionParameters;
        private _body = call parseBlock;

        private _node = [_parameterList,_body] call lambdaNode;
        _node breakout "parseLambda";
    };
};

parseUnaryOperation = {
    scopename "parseUnaryOperation";

    if (ACCEPT_SYM("var")) then {
        CONSUME();

        private _expression = [1,"="] call parseExpression;

        private _definitionNode = [_expression] call VariableDefinitionNode;
        _definitionNode breakout "parseUnaryOperation";
    };

    if (ACCEPT_TYPE("operator") && {(CURR_TOKEN select 1) in unaryOperators}) then {
        private _operator = CURR_TOKEN select 1;
        CONSUME();

        switch (_operator) do {
            case "--";
            case "++": {
                private "_unaryNode";

                if (ACCEPT_TYPE("identifier")) then {
                    // pre increment

                    private _identifier = CURR_TOKEN;

                    CONSUME();

                    private _unaryNode = [_operator,_identifier] call unaryOperationNode;
                    _preStatementNodeList pushback _unaryNode;
                } else {
                    // post increment
                    // backtrack to identifier

                    BACKTRACK();
                    BACKTRACK();

                    private _identifier = CURR_TOKEN;

                    CONSUME();
                    CONSUME();

                    private _unaryNode = [_operator,_identifier] call unaryOperationNode;
                    _postStatementNodeList pushback _unaryNode;
                };

                // dummy node for the sake of returning a value
                private _dummyNode = ["",""] call unaryOperationNode;
                _dummyNode breakout "parseUnaryOperation";
            };

            default {
                private _expressionNode = [] call parseExpression;
                if (!isnil "_expressionNode") then {
                    private _unaryNode = [_operator,_expressionNode] call unaryOperationNode;
                    _unaryNode breakout "parseUnaryOperation";
                } else {
                    hint "ERROR";
                };
            };
        };
    };

    if (ACCEPT_SYM("new")) then {
        CONSUME();

        private _instanceData = call parseFunctionCall;
        private _class = _instanceData select 1;
        private _arguments = _instanceData select 2;

        private _newInstanceNode = [_class,_arguments] call newInstanceNode;
        _newInstanceNode breakout "parseUnaryOperation";
    };

    if (ACCEPT_SYM("delete")) then {
        CONSUME();

        if (EXPECT_TYPE("identifier")) then {
            private _instance = CURR_TOKEN select 1;
            CONSUME();

            private _deleteInstanceNode = [_instance] call deleteInstanceNode;
            _deleteInstanceNode breakout "parseUnaryOperation";
        };
    };
};

parseAtom = {
    private "_node";

    scopename "parseAtom";

    if (ACCEPT_SYM("(")) then {
        CONSUME();
        _node = [1] call parseExpression;

        if (EXPECT_SYM(")")) then {
            if (!isnil "_node") then {
                CONSUME();
                _node breakout "parseAtom";
            } else {
                hint "ERROR: Invalid expression";
            };
        } else {
            hint "ERROR: Missing )";
        };
    };

    _node = call parseLiteral;
    if (!isnil "_node") exitwith {_node};

    _node = call parseLambda;
    if (!isnil "_node") exitwith {_node};

    _node = call parseFunctionCall;
    if (!isnil "_node") exitwith {_node};

    _node = call parseUnaryOperation;
    if (!isnil "_node") exitwith {_node};

    _node = call parseIdentifier;
    if (!isnil "_node") exitwith {_node};
};

// Use precedence climbing to obey operator precedence and associativity
// https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing/

parseExpression = {
    params ["_minPrecedence",["_terminator",""]];

    scopename "parseExpression";

    private _atomLHS = call parseAtom;

    while {
        !isnil "__token" &&
        { ((CURR_TOKEN select 1) in binaryOperators) } &&
        { ((CURR_TOKEN select 1) call getOperatorPrecedence) >= _minPrecedence } &&
        {(CURR_TOKEN select 1) != _terminator}
    } do {
        private _currSymbol = CURR_TOKEN select 1;
        private _opPrecedence = _currSymbol call getOperatorPrecedence;
        private _opAssociativity = _currSymbol call getOperatorAssociativity;

        private _nextMinPrecedence = _opPrecedence;
        if (_opAssociativity == "left") then {
            _nextMinPrecedence = _opPrecedence + 1;
        };

        CONSUME();
        private _atomRHS = [_nextMinPrecedence,_terminator] call parseExpression;

        // collapse result into left hande value

        switch (_currSymbol) do {
            case ".": {
                private _transform = {
                    // transform "this" -> "sqfpp_This" inside class methods
                    // yeah it's a hack
                    // get over it
                    if (_parsingContext == "class_definition" && {(_this select 0) == "identifier"} && {((_this select 1) select 1) == "this"}) then {
                        (_this select 1) set [1,"__sqfpp_this"];
                    };
                };

                if ((_atomRHS select 0) == "function_call") then {
                    _atomLHS call _transform;

                    _atomLHS = [_atomLHS, _atomRHS select 1, _atomRHS select 2] call methodCallNode;
                } else {
                    _atomLHS call _transform;

                    _atomLHS = [_atomLHS, _atomRHS] call classAccessNode;
                };
            };
            default {
                if (_currSymbol in assignmentOperators) then {
                    _atomLHS = [_atomLHS,_currSymbol,_atomRHS] call assignmentNode;
                } else {
                    _atomLHS = [_currSymbol,_atomLHS,_atomRHS] call binaryOperationNode;
                };
            };
        };
    };

    _atomLHS
};

parseAssignment = {
    scopename "parseAssignment";

    private _keywords = [];

    if (ACCEPT_SYM("var")) then {
        _keywords pushback "var";
        CONSUME();
    };

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN;
        private _identifierNode = [_identifier] call IdentifierNode;
        CONSUME();

        private _handled = false;

        if (ACCEPT_SYM(";")) then {
            // declaration

            CONSUME();

            _handled = true;

            private _node = [_keywords,"",_identifierNode,"__PARSER_DEFINITION"] call assignmentNode;
            _node breakout "parseAssignment";
        };

        if ((CURR_TOKEN select 1) in assignmentOperators) then {
            // initialization

            _handled = true;

            private _operator = CURR_TOKEN select 1;
            CONSUME();

            private _expressionNode = [1] call parseExpression;
            private _node = [_keywords,_operator,_identifierNode,_expressionNode] call assignmentNode;

            if (ACCEPT_SYM(";")) then {
                CONSUME();
            };

            _node breakout "parseAssignment";
        };

        if (!_handled) then {
            // not an assignment
            BACKTRACK();

            if !(_keywords isequalto []) then {
                hint "ERROR: Expected variable assignment";
            };
        };
    } else {
        if !(_keywords isequalto []) then {
            hint "ERROR: Expected Identifier";
            breakout "ast_generation";
        };
    };
};

parseBlock = {
    scopename "parseBlock";

    private _rawSQF = false;
    if (ACCEPT_SYM("SQF")) then {
        _rawSQF = true;
        CONSUME();
    };

    if (ACCEPT_SYM("{")) then {
        CONSUME();

        private "_node";
        if (!_rawSQF) then {
            private _statements = [];

            while {!ACCEPT_SYM("}")} do {
                _statements pushback (call parseStatement);
            };

            if (EXPECT_SYM("}")) then {
                CONSUME();

                _node = [_statements] call BlockNode;
            };
        } else {
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

            _node = [_sqfTokens] call rawSQFNode;
        };

        _node breakout "parseBlock";
    } else {
        if (_rawSQF) then {
            BACKTRACK();
        };
    };
};

// if (condition) {true block} else {false block}
// if (condition) statement; else statement;
parseIfStatement = {
    scopename "parseIfStatement";

    if (ACCEPT_SYM("if")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();
            private _conditionExpression = [1] call parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                private _trueBlock = [];
                private _falseBlock = [];

                // parse true block

                if (ACCEPT_SYM("{")) then {
                    _trueBlock = call parseBlock;
                } else {
                    private _statement = call parseStatement;
                    _trueBlock = [[_statement]] call BlockNode;
                };

                // parse false block

                if (ACCEPT_SYM("else")) then {
                    CONSUME();

                    if (ACCEPT_SYM("{")) then {
                        _falseBlock = call parseBlock;
                    } else {
                        private _statement = call parseStatement;
                        _falseBlock = [[_statement]] call BlockNode;
                    };
                };

                _node = [_conditionExpression,_trueBlock,_falseBLock] call ITENode;
                _node breakout "parseIfStatement";
            };
        };
    };
};

parseWhileStatement = {
    scopename "parseWhileStatement";

    if (ACCEPT_SYM("while")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();
            private _conditionExpression = [1] call parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                private _block = [];

                if (ACCEPT_SYM("{")) then {
                    _block = call parseBlock;
                } else {
                    private _statement = call parseStatement;
                    _block = [[_statement]] call BlockNode;
                };

                _node = [_conditionExpression,_block] call WhileNode;
                _node breakout "parseWhileStatement";
            };
        };
    };
};

parseForStatement = {
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
                BACKTRACK();
                BACKTRACK();

                // for-loop
                private _preStatement = call parseStatement;

                private _conditionStatement = [1] call parseExpression;
                CONSUME(); // remove ending semicolon

                private _postStatement = call parseStatement;

                if (EXPECT_SYM(")")) then {
                    CONSUME();

                    private _block = [];

                    if (ACCEPT_SYM("{")) then {
                        _block = call parseBlock;
                    } else {
                        private _statement = call parseStatement;
                        _block = [[_statement]] call BlockNode;
                    };

                    _node = [_preStatement,_conditionStatement,_postStatement,_block] call ForNode;
                    _node breakout "parseForStatement";
                };
            } else {
                // foreach
                BACKTRACK();
                BACKTRACK();

                if (EXPECT_SYM("var")) then {
                    CONSUME();

                    if (EXPECT_TYPE("identifier")) then {
                        private _enumerationVar = [CURR_TOKEN] call IdentifierNode;
                        CONSUME();

                        if (EXPECT_SYM(":")) then {
                            CONSUME();

                            private _list = [1] call parseExpression;

                            if (EXPECT_SYM(")")) then {
                                CONSUME();

                                private _block = [];

                                if (ACCEPT_SYM("{")) then {
                                    _block = call parseBlock;
                                } else {
                                    private _statement = call parseStatement;
                                    _block = [[_statement]] call BlockNode;
                                };

                                _node = [_list,_enumerationVar,_block] call ForeachNode;
                                _node breakout "parseForStatement";
                            };
                        };

                    };
                };
            };
        };
    };
};

/*
switch (condition) {
    case expression : {

    }

    defaul {

    }
}
*/
parseSwitchStatement = {
    scopename "parseSwitchStatement";

    if (ACCEPT_SYM("switch")) then {
        CONSUME();

        if (EXPECT_SYM("(")) then {
            CONSUME();

            private _switchCondition = [1] call parseExpression;

            if (EXPECT_SYM(")")) then {
                CONSUME();

                if (EXPECT_SYM("{")) then {
                    CONSUME();

                    private _cases = [];

                    while {ACCEPT_SYM("case") || {ACCEPT_SYM("default")}} do {
                        private _caseCondition = [];

                        if (ACCEPT_SYM("case")) then {
                            CONSUME();
                            _caseCondition = [1] call parseExpression;
                        } else {
                            CONSUME();
                        };

                        if (EXPECT_SYM(":")) then {
                            CONSUME();

                            private _caseBlock = call parseBlock;
                            _cases pushback [_caseCondition,_caseBlock];
                        };
                    };

                    if (EXPECT_SYM("}")) then {
                        CONSUME();

                        private _switchNode = [_switchCondition,_cases] call SwitchNode;
                        _switchNode breakout "parseSwitchStatement";
                    };
                };
            };
        };
    };
};

parseFunctionParameters = {
    private _parameterList = [];

    if (EXPECT_SYM("(")) then {
        CONSUME();

        while {!ACCEPT_SYM(")")} do {
            // parse valid var types

            private _validTypes = [];
            while {
                ACCEPT_TYPE("identifier") &&
                {
                    private _type = CURR_TOKEN select 1;
                    typeMap findif {_type == (_x select 0)} != -1
                }
            } do {
                _validTypes pushbackunique (CURR_TOKEN select 1);
                CONSUME();

                // this allows for trailing commas but w/e
                if ((CURR_TOKEN select 1) == ",") then {
                    CONSUME();
                };
            };
            if (_validTypes findif {_x == "any"} != -1) then {_validTypes = []};

            // grab var name
            // check for validity, no need to handle manually
            // since expect macro will break parsing
            if (EXPECT_TYPE("identifier")) then {};
            private _parameterName = CURR_TOKEN select 1;
            CONSUME();

            // parse optional default value

            private _defaultValue = "sqfpp_defValue";
            if (ACCEPT_SYM("=")) then {
                CONSUME();

                _defaultvalue = [1] call parseExpression;
            };

            // remove comma, prep for next parameter
            // this allows for trailing commas but w/e
            if ((CURR_TOKEN select 1) == ",") then {
                CONSUME();
            };

            private _parameterNode = [_validTypes,_parameterName,_defaultvalue] call functionParameterNode;
            _parameterList pushback _parameterNode;
        };

        // consume closing parenthesis
        CONSUME();
    };

    _parameterList
};

// function add(number,string _a = 0, number,string _b = 0) { return _a + _b; }
parseNamedFunctionDefinition = {
    scopename "parseNamedFunctionDefinition";

    if (ACCEPT_SYM("function")) then {
        CONSUME();

        if (ACCEPT_TYPE("identifier")) then {
            private _identifier = CURR_TOKEN select 1;
            CONSUME();

            private _parameterList = call parseFunctionParameters;
            private _body = call parseBlock;

            private _functionNode = [_identifier,_parameterList,_body] call namedFunctionNode;
            _functionNode breakout "parseNamedFunctionDefinition";
        } else {
            hint "ERROR: Function definition missing name"
        };
    };
};

parseNularStatements = {
    scopename "parseNularStatements";

    if (ACCEPT_SYM("break")) then {
        CONSUME();

        if (ACCEPT_SYM(";")) then {
            CONSUME();

            private _nularNode = ["break"] call nularStatementNode;
            _nularNode breakout "parseNularStatements";
        } else {
            BACKTRACK();
        };
    };
};

parseUnaryStatements = {
    scopename "parseUnaryStatements";

    if (ACCEPT_SYM("return")) then {
        CONSUME();

        // empty return statement

        if (ACCEPT_SYM(";")) then {
            CONSUME();

            private _unaryNode = ["return", []] call UnaryStatementNode;
            _unaryNode breakout "parseUnaryStatements";
        };

        // return a value

        private _expression = [1] call parseExpression;

        if (EXPECT_SYM(";")) then {
            CONSUME();

            private _unaryNode = ["return", _expression] call UnaryStatementNode;
            _unaryNode breakout "parseUnaryStatements";
        };
    };
};

parseClassDefinition = {
    scopename "parseClassDefinition";

    if (ACCEPT_SYM("class")) then {
        CONSUME();

        _parsingContext = "class_definition";

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
                        if (_parentsLeft) then {
                            hint "ERROR: Trailing Comma";
                        };
                    };

                    if ((CURR_TOKEN select 1) == ",") then {
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

                            if (ACCEPT_TYPE("identifier")) then {
                                private _identifier = CURR_TOKEN select 1;

                                CONSUME();

                                if (EXPECT_SYM("=")) then {
                                    CONSUME();

                                    private _value = [1] call parseExpression;

                                    if (EXPECT_SYM(";")) then {
                                        CONSUME();

                                        _vars pushback [_identifier,_value];

                                        breakto "classDefinitionParseLoop";
                                    };
                                };
                            };
                        };

                        private _node = call parseNamedFunctionDefinition;
                        if (!isnil "_node") then {
                            // all methods take the instance object_
                            // as the first parameter
                            private _methodParameters = [(+methodInstanceParameter)] + (_node select 2);

                            _funcs pushback [_node select 1, _methodParameters, _node select 3];
                            breakto "classDefinitionParseLoop";
                        };
                    };
                };

                if (EXPECT_SYM("}")) then {
                    CONSUME();

                    // create class node
                    private _node = [_classname,_parentClassnames,_vars,_funcs] call classDefinitionNode;

                    _parsingContext = "";
                    _node breakout "parseClassDefinition";
                };
            };
        };
    };
};

parseStatement = {
    private "_node";

    if (ACCEPT_SYM(";")) exitwith {CONSUME(); ["empty_statement"]};


    _node = call parseNularStatements;
    if (!isnil "_node") exitwith {_node};

    _node = call parseUnaryStatements;
    if (!isnil "_node") exitwith {_node};

    //_node = call parseAssignment;
    //if (!isnil "_node") exitwith {_node};

    _node = call parseIfStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call parseWhileStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call parseForStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call parseSwitchStatement;
    if (!isnil "_node") exitwith {_node};

    _node = call parseNamedFunctionDefinition;
    if (!isnil "_node") exitwith {_node};

    _node = call parseClassDefinition;
    if (!isnil "_node") exitwith {_node};

    // function definition

    // unnamed scope
    private _node = call parseBlock;
    if (!isnil "_node") exitwith {
        ["unnamed_scope", _node]
    };

    _node = [1] call parseExpression;
    if (!isnil "_node") exitwith {
        if (EXPECT_SYM(";")) then {
            CONSUME();

            // change this node's type instead of
            // creating a containing node
            // reduce parenthesis in translated code
            ["expression_statement", _node]
        };
    };

    // unrecognized token
    CONSUME();
};