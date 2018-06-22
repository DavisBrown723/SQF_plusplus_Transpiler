parserCreate = {
    params ["_source"];

    private _lexer = [_source] call lexerCreate;
    private _ast = [];

    private _tokens = (_lexer select 1) select { !((_x select ) in ["whitespace","end_line"]) };

    // generate AST

    private _tokenCount = count _tokens;
    private _tokenPointer = 0;

    private _statementNodeList = [];
    private _ast = [_statementNodeList] call BlockNode;

    while {_tokenPointer < _tokenCount} do {
        call parseStatement;
    };

    [_ast]
};