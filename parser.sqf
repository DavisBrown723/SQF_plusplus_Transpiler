// recursive descent parser with backtracking

#define CURR_TOKEN          __token

#define ADVANCE()           _tokenPointer = _tokenPointer + 1;
#define REGRESS()           _tokenPointer = (_tokenPointer - 1) max 0;

#define TOKENS_LEFT()       (_tokenPointer < _tokenCount - 1)

#define NEXT_SYM()          ADVANCE(); CURR_TOKEN = _tokens select _tokenPointer;
#define BACKTRACK()         REGRESS(); CURR_TOKEN = _tokens select _tokenPointer;

#define ACCEPT_SYM(char)    (!isnil "__token" && {(CURR_TOKEN select 1) == char})
#define ACCEPT_TYPE(char)   (!isnil "__token" && {(CURR_TOKEN select 0) == char})

#define EXPECT_SYM(char)    (if (ACCEPT_SYM(char))  then {true} else { hint "EXPECT ERROR"; breakto "ast_generation" })
#define EXPECT_TYPE(char)   (if (ACCEPT_TYPE(char)) then {true} else { hint "EXPECT ERROR"; breakto "ast_generation" })

// Wishlist
// subscript operator : array[0][2];

// Refactor priorities
// we use way too much breakto/breakout right now
// proper error handling and feedback

parserCreate = {
    params ["_source"];

    private _lexer = [_source] call lexerCreate;
    private _tokens = (_lexer select 1) select { !((_x select 0) in ["whitespace","end_line"]) };

    tokens = _tokens; // #TODO: remove

    // generate AST

    private _tokenCount = count _tokens;
    private _tokenPointer = -1; // will be incremented by first NEXT_SYM() call

    private _ast = [];

    if (_tokenCount > 0) then {

        scopename "ast_generation";
        private "__token";
        while {_tokenPointer < _tokenCount} do {
            NEXT_SYM();
            _ast pushback (call parseStatement);
        };

    };

    _ast = _ast call BlockNode;
    ast = _ast; // #TODO: remove

    [_ast]
};



// Define Node Classes

// [condition,true BlockNode,false BlockNode]
ITENode = {
    params ["_condition","_trueBlock","_falseBlock"];

    ["if",_condition,_trueBlock,_falseBlock]
};

// [statementnode array]
BlockNode = {
    params [["_statementList",[]]];

    ["block", _statementList];
};

// [keywords,operator,identifier,expression node]
assignmentNode = {
    params ["_keywords","_operator","_left","_right"];

    ["Assignment",_keywords,_operator,_left,_right]
};

// ["identifier", identifier]
identifierNode = {
    params ["_identifier"];

    ["identifier", _identifier select 1]
};

// ["literal",literal token]
literalNode = {
    params ["_literalToken"];

    ["literal", _literalToken select 1]
};


// [operator,right]
unaryOperationNode = {
    params ["_operator","_right"];

    ["unary",_operator,_right]
};

// [operator,left Expression,right Expression]
binaryOperationNode = {
    params ["_operator","_left","_right"];

    ["binary",_operator,_left,_right]
};

// [identifier,arguments]
functionCallNode = {
    params ["_function","_arguments"];

    ["function_call", _function, _arguments]
};



/*
    "Grammar" (wip)

    () = optional
    {} = repeating sequence until pattern broken
    -> = next token
     | = alternative sequence
    --------------------------------

    arrayLiteral: [ -> {expression -> (,)} -> ]
    literal : number | string | bool | array
    unaryOperation : operator -> expression
    binaryOperation : expression -> operator -> expression

    expression = literal | unary | binary | function call | identifier | expression
    assignment : (var) identifier -> ; | = -> expression

    statement: assignment | expression
    block: [statement,statement,...]
*/

// Parse Methods

parseIdentifier = {
    scopename "parseIdentifier";

    if (ACCEPT_TYPE("identifier")) then {
        private _identifierNode = [CURR_TOKEN] call identifierNode;
        NEXT_SYM();
        _identifierNode breakout "parseIdentifier";
    };
};

parseLiteral = {
    scopename "parseLiteral";

    if (ACCEPT_TYPE("number_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("string_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseLiteral";
    };

    if (ACCEPT_TYPE("bool_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseLiteral";
    };

    // parse array literal
    if (ACCEPT_SYM("[")) then {
        NEXT_SYM();

        if (ACCEPT_SYM("]")) then {
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

            private _expressionNode = 1 call parseExpression;
            _argExpressions pushback _expressionNode;

            if ((CURR_TOKEN select 1) == ",") then {
                NEXT_SYM();
                _argsLeft = true;
            };
        };

        if (EXPECT_SYM("]")) then {
            NEXT_SYM();

            private _literalNode = [["array_literal", _argExpressions]] call literalNode;
            _literalNode breakout "parseLiteral";
        };
    };
};

parseFunctionCall = {
    scopename "parseFunctionCall";

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        NEXT_SYM();

        if (ACCEPT_SYM("(")) then {
            NEXT_SYM();

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

                    private _expressionNode = 1 call parseExpression;
                    _argExpressions pushback _expressionNode;

                    //if (ACCEPT_SYM(",")) then {
                    if ((CURR_TOKEN select 1) == ",") then {
                        NEXT_SYM();
                        _argsLeft = true;
                    };
                };
            };

            if (EXPECT_SYM(")")) then {
                NEXT_SYM();
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

parseUnaryOperation = {
    scopename "parseUnaryOperation";

    if (ACCEPT_TYPE("operator") && {(CURR_TOKEN select 1) in unaryOperators}) then {
        private _operator = CURR_TOKEN select 1;
        NEXT_SYM();

        private _expressionNode = call parseExpression;
        if (!isnil "_expressionNode") then {
            private _unaryNode = [_operator,_expressionNode] call unaryOperationNode;
            _unaryNode breakout "parseUnaryOperation";
        } else {
            hint "ERROR";
        };
    };
};

parseAtom = {
    private "_node";

    scopename "parseAtom";

    if (ACCEPT_SYM("(")) then {
        NEXT_SYM();
        _node = 1 call parseExpression;

        if (EXPECT_SYM(")")) then {
            if (!isnil "_node") then {
                NEXT_SYM();
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

    _node = call parseFunctionCall;
    if (!isnil "_node") exitwith {_node};

    _node = call parseIdentifier;
    if (!isnil "_node") exitwith {_node};

    _node = call parseUnaryOperation;
    if (!isnil "_node") exitwith {_node};
};

// Use precedence climbing to obey operator precedence and associativity
// https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing/

parseExpression = {
    private _minPrecedence = _this;

    scopename "parseExpression";

    private _atomLHS = call parseAtom;

    while {
        !isnil "__token" &&
        { ((CURR_TOKEN select 1) in binaryOperators) } &&
        { ((CURR_TOKEN select 1) call getOperatorPrecedence) >= _minPrecedence }
    } do {
        private _currSymbol = CURR_TOKEN select 1;
        private _opPrecedence = _currSymbol call getOperatorPrecedence;
        private _opAssociativity = _currSymbol call getOperatorAssociativity;

        private _nextMinPrecedence = _opPrecedence;
        if (_opAssociativity == "left") then {
            _nextMinPrecedence = _opPrecedence + 1;
        };

        NEXT_SYM();
        private _atomRHS = _nextMinPrecedence call parseExpression;

        _atomLHS = [_currSymbol,_atomLHS,_atomRHS] call binaryOperationNode;
    };

    _atomLHS
};

parseAssignment = {
    scopename "parseAssignment";

    private _keywords = [];

    if (ACCEPT_SYM("var")) then {
        _keywords pushback "var";
        NEXT_SYM();
    };

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        NEXT_SYM();

        private _handled = false;

        if (ACCEPT_SYM(";")) then {
            // declaration

            _handled = true;

            private _node = [_keywords,"",_identifier,"__PARSER_DEFINITION"] call assignmentNode;
            _node breakout "parseAssignment";
        };

        if (ACCEPT_SYM("=")) then {
            // initialization

            _handled = true;

            NEXT_SYM();

            private _expressionNode = 1 call parseExpression;
            private _node = [_keywords,"=",_identifier,_expressionNode] call assignmentNode;

            if (EXPECT_SYM(";")) then {
                NEXT_SYM();

                _node breakout "parseAssignment";
            };
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

    if (ACCEPT_SYM("{")) then {
        NEXT_SYM();

        private _statements = [];

        while {!ACCEPT_SYM("}")} do {
            _statements pushback (call parseStatement);
        };

        NEXT_SYM();

        private _node = _statements call BlockNode;
        _node breakout "parseBlock";
    };
};

// if (condition) {true block} else {false block}
parseIfStatement = {
    scopename "parseIfStatement";

    if (ACCEPT_SYM("if")) then {
        NEXT_SYM();

        if (EXPECT_SYM("(")) then {
            NEXT_SYM();
            private _conditionExpression = 1 call parseExpression;

            if (EXPECT_SYM(")")) then {
                NEXT_SYM();

                if (ACCEPT_SYM("{")) then {
                    // 2 blocks

                    private _trueBlock = call parseBlock;

                    if (ACCEPT_SYM("else")) then {
                        NEXT_SYM();

                        private _falseBLock = call parseBlock;

                        private _node = [_conditionExpression,_trueBlock,_falseBLock] call ITENode;
                        _node breakout "parseIfStatement";
                    };

                    private _node = [_conditionExpression,_trueBlock,[]] call ITENode;
                    _node breakout "parseIfStatement";
                } else {
                    // 2 single statements

                    private _statement = call parseStatement;
                    private _trueBlock = [_statement] call BlockNode;

                    if (ACCEPT_SYM("else")) then {
                        NEXT_SYM();

                        private _statement = call parseStatement;
                        private _falseBlock = [_statement] call BlockNode;

                        private _node = [_conditionExpression,_trueBlock,_falseBlock] call ITENode;
                        _node breakout "parseIfStatement";
                    };

                    private _node = [_conditionExpression,_trueBlock,[]] call ITENode;
                    _node breakout "parseIfStatement";
                };
            };
        };
    };
};

parseStatement = {
    private "_node";

    _node = call parseAssignment;
    if (!isnil "_node") exitwith {_node};

    _node = call parseIfStatement;
    if (!isnil "_node") exitwith {_node};

    _node = 1 call parseExpression;
    if (!isnil "_node") exitwith {_node};
};