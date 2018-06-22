// recursive descent parser with backtracking

#define CURR_TOKEN          __token

#define ADVANCE()           _tokenPointer = _tokenPointer + 1
#define REGRESS()           _tokenPointer = _tokenPointer - 1

#define NEXT_SYM()          CURR_TOKEN = _tokens select _tokenPointer; ADVANCE()

#define BACKTRACK()         REGRESS(); CURR_TOKEN = _tokens select _tokenPointer

#define ACCEPT_SYM(char)    if ((CURR_TOKEN select 1) == char) then {true} else {false}
#define ACCEPT_TYPE(char)   if ((CURR_TOKEN select 0) == char) then {true} else {false}

#define EXPECT_SYM(char)    if (ACCEPT_SYM(char)) then {true} else { breakto "ast_generation"; false }
#define EXPECT_TYPE(char)   if (ACCEPT_TYPE(char)) then {true} else { breakto "ast_generation"; false }



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
    Grammar (wip)

    Block : Statement[]

    Definition : var -> identifier -> ;
    Initialization var -> identifier -> = -> expression -> ;
    Assignment : identifier -> = -> expression

    UnaryOperation : operator -> expression
    BinariyOperation : expression -> operator -> expression

    literal : number | string | bool | array
    expression = literal | identifier | unary | binary | function call | expression
    statement: definition | initialization | assignment | function call | binary expression



    var _x;
    var _x = 5;
    _x = 10;

    nular();
    unary(arg1);
    binary(arg1,arg2);
    func(arg1,arg2,arg3,...);
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

    [_operator,_right]
};

// [operator,left Expression,right Expression]
BinaryOperationNode = {
    params ["_operator","_left","_right"];

    [_operator,_left,_right]
};

parseLiteral = {
    scopename "parseLiteral";

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

/*
parseExpression = {
    parseBinaryOperation
    parseUnaryOperation
    parseFunctionCall
    parseConditionalExpression
};
*/

parseExpression = {
    scopename "parseExpression";

    private "_node";

    _node = call parseLiteral;
    if (isnil "_node") then {_node breakout "parseExpression"};
};

parseAssignment = {
    private _keywords = [];

    if (ACCEPT_SYM("var")) then {
        _keywords pushback "var";
        NEXT_SYM();
    };

    if (EXPECT_TYPE("identifier")) then {
        private _identifier = CURR_TOKEN select 1;
        NEXT_SYM();

        if (ACCEPT_SYM(";")) then {
            // declaration

            //[_identifier] call ;
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
        hint "ERROR: Expected Identifier";
    };
};

parseStatement = {
    scopename "parseStatement";

    call parseAssignment;
    //call parseFunctionCall;
    //call parseBinaryExparession
};