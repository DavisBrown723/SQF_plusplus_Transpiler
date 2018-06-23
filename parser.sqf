// recursive descent parser with backtracking

#define CURR_TOKEN          __token

#define ADVANCE()           _tokenPointer = _tokenPointer + 1
#define REGRESS()           _tokenPointer = _tokenPointer - 1

#define NEXT_SYM()          CURR_TOKEN = _tokens select _tokenPointer; ADVANCE()

#define BACKTRACK()         REGRESS(); CURR_TOKEN = _tokens select _tokenPointer

#define ACCEPT_SYM(char)    if ((CURR_TOKEN select 1) == char) then {true} else {false}
#define ACCEPT_TYPE(char)   if ((CURR_TOKEN select 0) == char) then {true} else {false}

#define EXPECT_SYM(char)    if (ACCEPT_SYM(char)) then {true} else { breakto "ast_generation" }
#define EXPECT_TYPE(char)   if (ACCEPT_TYPE(char)) then {true} else { breakto "ast_generation" }


// we use way too much breakto/breakout right now
// save it for the refactor

parserCreate = {
    params ["_source"];

    private _lexer = [_source] call lexerCreate;
    private _tokens = (_lexer select 1) select { !((_x select 0) in ["whitespace","end_line"]) };

    // generate AST

    private _tokenCount = count _tokens;
    private _tokenPointer = 0;

    private _ast = [] call BlockNode;
    ast = _ast;

    scopename "ast_generation";
    private __token = ["",""];
    private __prevToken = ["",""];
    while {_tokenPointer < _tokenCount} do {
        NEXT_SYM();
        call parseStatement;
    };

    [_ast]
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


// Define Node Classes

// [condition,true BlockNode,false BlockNode]
ITENode = {
    params ["_condition","_trueBlock","_falseBlock"];

    [_condition,_trueBlock,_falseBlock]
};

// [statementnode array]
BlockNode = {
    params [["_statementList",[]]];

    _statementList
};

// [keywords,operator,identifier,expression node]
AssignmentNode = {
    params ["_keywords","_operator","_left","_right"];

    ["Assignment",_keywords,_operator,_left,_right]
};

// ["literal",literal token]
literalNode = {
    params ["_literalToken"];

    ["literal", _literalToken select [0,2]]
};


// [operator,right]
UnaryOperationNode = {
    params ["_operator","_right"];

    ["unary",_operator,_right]
};

// [operator,left Expression,right Expression]
BinaryOperationNode = {
    params ["_operator","_left","_right"];

    ["binary",_operator,_left,_right]
};

parseLiteral = {
    scopename "parseLiteral";

    if (ACCEPT_SYM("(")) then {
        NEXT_SYM();
        _inParenthesis = true;
    };

    if (ACCEPT_TYPE("number_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseExpression";
    };

    if (ACCEPT_TYPE("string_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseExpression";
    };

    if (ACCEPT_TYPE("bool_literal")) then {
        private _literalNode = [CURR_TOKEN] call literalNode;
        NEXT_SYM();
        _literalNode breakout "parseExpression";
    };

    // #TODO: Arrays : [ -> expression (--> , --> expression) --> ]
};

parseUnaryOperation = {
    scopename "parseUnaryOperation";

    if (ACCEPT_TYPE("operator") && {(CURR_TOKEN select 1) in unaryOperators}) then {
        private _operator = CURR_TOKEN select 1;
        NEXT_SYM();

        private _expressionNode = call parseExpression;
        if (!isnil "_expressionNode") then {
            private _unaryNode = [_operator,_expressionNode] call UnaryOperationNode;
            _unaryNode breakout "parseUnaryOperation";
        } else {
            hint "ERROR";
        };
    };
};

parseBinaryOperation = {
    // parse left expression
    // expect binary operator
    // parse right expression


    // how do we respect operator precedence?

    // how do we backtrack the first expression
    // if no binary operator is found in the middle?
};

parseExpression = {
    scopename "parseExpression";

    private "_node";

    private _inParenthesis = false;

    if (ACCEPT_SYM("(")) then {
        NEXT_SYM();
        _inParenthesis = true;
    };


    _node = call parseUnaryOperation;
    if (!isnil "_node") then {_node breakout "parseExpression"};

    _node = call parseLiteral;
    if (!isnil "_node") then {_node breakout "parseExpression"};


    if (_inParenthesis) then {
        if (EXPECT_SYM(")")) then {
            NEXT_SYM();
        } else {
            hint "ERROR: Missing )";
        };
    };
};

parseAssignment = {
    private _keywords = [];

    if (ACCEPT_SYM("var")) then {
        _keywords pushback "var";
        NEXT_SYM();
    };

    if (ACCEPT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        NEXT_SYM();

        if (ACCEPT_SYM(";")) then {
            // declaration

            _ast pushback ([_keywords,"",_identifier,"__PARSER_DEFINITION"] call AssignmentNode);
            breakout "parseStatement";
        };

        if (EXPECT_SYM("=")) then {
            // initialization

            NEXT_SYM();

            private _expressionNode = call parseExpression;
            _ast pushback ([_keywords,"=",_identifier,_expressionNode] call AssignmentNode);

            if !(EXPECT_SYM(";")) then {
                hint "ERROR: Missing ;";
            };
            breakout "parseStatement";
        };

        if (_keywords isequalto []) then {
            // not an assignment
            BACKTRACK();
        } else {
            hint "ERROR: Expected variable assignment";
        };
    } else {
        if !(_keywords isequalto []) then {
            hint "ERROR: Expected Identifier";
            breakout "ast_generation";
        };
    };
};

parseStatement = {
    scopename "parseStatement";

    call parseAssignment;
    call parseExpression;
};