// define tokens

keywords = ["var","if","while","for","switch","break"];

letters =
    ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
    +
    ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];

digits = ["0","1","2","3","4","5","6","7","8","9"];

separators = [ "," , "(" , ")" , "[", "]", "{" , "}" , ":" ];

assignmentOperators = ["=","+=","-=","*=","/=","%="];
singleCharOperators = [ "=",  "!" , "+" , "-" , "*" , "/" , "%" , ">" , "<" , "." ];
doubleCharOperators = [ "+=","-","*=","/=","%=",  "<=",">=","==","!=","&&","||","++","--"];

unaryOperators = ["!","++","--"];
binaryOperators = singleCharOperators + doubleCharOperators - unaryOperators;

identifierStartChars = letters + ["_"];
identifierChars = identifierStartChars + digits;

numberStartChars = digits;
numberChars = digits + ["."];

stringStartChars = ['""' call stringToNum,"''" call stringToNum];
booleanLiterals = ["true","false"];

arrayStartChar = "[";
arrayEndChar = "]";

endline = endl select [1,1];
whitespace = [" "];
semicolon = ";";


operatorInfoMap = [
    [".",  8,"left"],

    ["++", 7,"left"],
    ["--", 7,"left"],

    ["*",  6,"left"],
    ["/",  6,"left"],
    ["%",  6,"left"],

    ["+",  5,"left"],
    ["-",  5,"left"],

    ["<",  4,"left"],
    [">",  4,"left"],
    ["<=", 4,"left"],
    [">=", 4,"left"],

    ["==", 3,"left"],
    ["!=", 3,"left"],

    ["&&", 2,"left"],
    ["||", 2,"left"],

    ["=",  1,"left"],
    ["+=", 1,"left"],
    ["-=", 1,"left"],
    ["*=", 1,"left"],
    ["/=", 1,"left"],
    ["%=", 1,"left"]
];

getOperatorPrecedence = {
    private _opIndex = operatorInfoMap findif {(_x select 0) == _this};
    (operatorInfoMap select _opIndex) select 1
};

getOperatorAssociativity = {
    private _opIndex = operatorInfoMap findif {(_x select 0) == _this};
    (operatorInfoMap select _opIndex) select 2
};

// used to convert function argument types
// for use with params command
typeMap = [
    ["any", "[]"],

    ["number", "0"],
    ["bool", "true"],
    ["array", "[]"],
    ["string", "''"],
    ["function", "{}"],

    ["object", "objnull"],
    ["side", "east"],
    ["config", "confignull"],
    ["group", "grpnull"],

    ["control", "controlnull"],
    ["display", "displaynull"],

    ["thread", "scriptnull"],
    ["group", "grpnull"]

    //["text", "composeText ['']"]
];

typeToSQFType = {
    private _typeIndex = typeMap findif {(_x select 0) == _this};
    if (_typeIndex != -1) then {(typeMap select _typeIndex) select 1};
};

// parser

lexerCreate = {
    params ["_source"];

    private _scanner = [_source] call scannerCreate;

    private "_token";
    private _currLine = 1;
    private _tokens = [];
    while {
        _token = _scanner call lexerNext;
        (_token select 0) != "end_of_file"
    } do {
        _tokens pushback _token;
    };

    [_scanner,_tokens]
};

lexerNext = {
    private _scanner = _this;

    // start

    private _char1 = _scanner call scannerNext;
    private _char2 = [_scanner] call scannerPeek;

    private _twoCharArray = (toarray _char1) + (toarray _char2);
    private _nextTwoChars = _char1 + _char2;

    scopename "token_categorization";

    // create new token

    if (_char1 ==  endline) then {
        private _line = _currLine;
        _currLine = _currLine + 1;
        ["end_line",_char1,_line] breakout "token_categorization";
    };

    if (_char1 in whitespace) then {
        private _whitespace = _char1;

        _char1 = [_scanner] call scannerPeek;
        while {_char1 in whitespace} do {
            _scanner call scannerNext; // advance past last read char
            _whitespace = _whitespace + _char1;
            _char1 = [_scanner] call scannerPeek;
        };

        ["whitespace", _whitespace,_currLine] breakout "token_categorization";
    };

    /*
    // handle block comments
    if (_nextTwoChars == "/*") then {
        private _comment = _nextTwoChars;

        // make sure
        // char1 = "/"
        // char2 = "*"
        _scanner call scannerNext;

        while {_char1 != "*" || _char2 != "/"} do {
            _char1 = _scanner call scannerNext;
            _char2 = [_scanner] call scannerPeek;

            _comment = _comment + _char1;
        };

        _comment = _comment + _char2;
        _scanner call scannerNext;

        ["block_comment", _comment] breakout "token_categorization";
    };

    // handle single-line comments
    private _slashNum = "/" call stringToNum;
    if ([_char1 call stringToNum,_char2 call stringToNum] isequalto [_slashNum,_slashNum]) then {
        _scanner call scannerNext;
        ["comment", ""] breakout "token_categorization";
    };
    */

    if (_char1 == semicolon) then {
        ["semicolon", _char1,_currLine] breakout "token_categorization";
    };

    if (_char1 in identifierStartChars) then {
        private _identifier = _char1;

        _char1 = [_scanner] call scannerPeek;
        while {_char1 in identifierChars} do {
            _scanner call scannerNext;
            _identifier = _identifier + _char1;
            _char1 = [_scanner] call scannerPeek;
        };

        // match keywords

        private _tokenType = "identifier";
        private _lowercaseIdentifier = tolower _identifier;

        if (_lowercaseIdentifier in keywords) then {
            _tokenType = "keyword";
        };

        // match bool literals

        if (_lowercaseIdentifier in booleanLiterals) then {
            _tokenType = "bool_literal";
        };

        [_tokenType,_identifier,_currLine] breakout "token_categorization";
    };

    if (_char1 in numberStartChars) then {
        private _number = _char1;

        _char1 = [_scanner] call scannerPeek;
        while {_char1 in numberChars} do {
            _scanner call scannerNext;
            _number = _number + _char1;
            _char1 = [_scanner] call scannerPeek;
        };

        ["number_literal", _number, _currLine] breakout "token_categorization";
    };

    if ((_char1 call stringToNum) in stringStartChars) then {
        // remember the quoteChar (single or double quote)
        // so we can look for the same character to terminate the quote

        private _startChar = _char1;
        private _string = _char1;

        _char1 = _scanner call scannerNext;
        while {_char1 != _startChar} do {
            _string = _string + _char1;
            _char1 = _scanner call scannerNext;
        };

        _string = _string + _char1; // close quote

        ["string_literal", _string, _currLine] breakout "token_categorization";
    };

    private _symbol = _char1 + _char2;
    if (_symbol in doubleCharOperators) then {
        _scanner call scannerNext;
        ["operator", _symbol, _currLine] breakout "token_categorization";
    };

    if (_char1 in singleCharOperators) then {
        ["operator", _char1, _currLine] breakout "token_categorization";
    };

    if (_char1 in separators) then {
        ["separator", _char1, _currLine] breakout "token_categorization";
    };

    if (_char1 == "eof") then {
        ["end_of_file","", _currLine] breakout "token_categorization";
    };

    // default

    ["unknown_token", _char1, _currLine]
};