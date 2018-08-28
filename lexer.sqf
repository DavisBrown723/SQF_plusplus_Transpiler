// define lexer rules

sqfpp_letters =
    ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
    +
    ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];

sqfpp_digits = ["0","1","2","3","4","5","6","7","8","9"];
sqfpp_separators = [ "," , "(" , ")" , "[", "]", "{" , "}" , ":" ];

sqfpp_operatorChars = [ "=",  "!" , "+" , "-" , "*" , "/" , "%" , ">" , "<" , ".", "&", "|" ];
sqfpp_assignmentOperators = ["=","+=","-=","*=","/=","%="];

sqfpp_identifierStartChars = sqfpp_letters + ["_"];
sqfpp_identifierChars = sqfpp_identifierStartChars + sqfpp_digits;

sqfpp_numberStartChars = sqfpp_digits;
sqfpp_numberChars = sqfpp_digits + ["."];

sqfpp_stringStartChars = [
    (toarray '""') select 0,
    (toarray "''") select 0
];

sqfpp_endlAvailable = (productversion select 2) >= 170;
sqfpp_endl = if (sqfpp_endlAvailable) then { endl } else { tostring [10] };

sqfpp_endline = if (sqfpp_endlAvailable) then { sqfpp_endl select [1,1] } else { sqfpp_endl };
sqfpp_whitespace = " ";


sqfpp_operatorInfoMap = [
    [".",  9,"left", ["binary"]],

    ["!",  8,"right", ["unary"]],

    ["*",  7,"left", ["binary"]],
    ["/",  7,"left", ["binary"]],
    ["%",  7,"left", ["binary"]],

    ["+",  6,"left", ["binary"]],
    ["-",  6,"left", ["binary","unary"]],

    ["<",  5,"left", ["binary"]],
    [">",  5,"left", ["binary"]],
    ["<=", 5,"left", ["binary"]],
    [">=", 5,"left", ["binary"]],

    ["==", 4,"left", ["binary"]],
    ["!=", 4,"left", ["binary"]],

    ["&&", 3,"left", ["binary"]],
    ["||", 3,"left", ["binary"]],

    ["=",  2,"right", ["binary","assignment"]],
    ["+=", 2,"right", ["binary","assignment"]],
    ["-=", 2,"right", ["binary","assignment"]],
    ["*=", 2,"right", ["binary","assignment"]],
    ["/=", 2,"right", ["binary","assignment"]],
    ["%=", 2,"right", ["binary","assignment"]],
    ["<<", 2,"right", ["binary"]],
    [">>", 2,"right", ["binary"]],

    ["new",         1,"right", ["unary"]],
    ["delete",      1,"right", ["unary"]],
    ["copy",        1,"right", ["unary"]],
    ["init_super",  1,"right", ["unary"]]
];

sqfpp_fnc_getOperatorInfo = {
    private _index = sqfpp_operatorInfoMap findif {(_x select 0) == _this};

    if (_index != -1) then {
        sqfpp_operatorInfoMap select _index
    };
};

// used to convert function parameter types
// for use with params command
sqfpp_typeMap = [
    ["any", ""],

    ["number",      "0"],
    ["bool",        "true"],
    ["array",       "[]"],
    ["string",      "''"],
    ["function",    "{}"],

    ["object",      "objnull"],
    ["side",        "east"],
    ["config",      "confignull"],
    ["group",       "grpnull"],
    ["location",    "locationnull"],
    ["Class",       "locationnull"], // syntactical sugar

    ["control",     "controlnull"],
    ["display",     "displaynull"],

    ["thread",      "scriptnull"],
    ["group",       "grpnull"]

    //["text", "composeText ['']"]
];

sqfpp_fnc_isValidType = {
    private _typeIndex = sqfpp_typeMap findif {(_x select 0) == _this};

    _typeIndex != -1
};

sqfpp_fnc_typeToSQFType = {
    private _index = sqfpp_typeMap findif {(_x select 0) == _this};

    if (_index != -1) then {
        (sqfpp_typeMap select _index) select 1
    };
};

sqfpp_keywordMap = [
    ["bool_literal", [
        "true",
        "false"
    ]],
    ["nular", [
        "break",
        "continue"
    ]],
    ["unary", [
        "return"
    ]],
    ["raw_sqf_indicator", [
        "SQF"
    ]]
];

sqfpp_fnc_findKeywordsByType = {
    private _index = sqfpp_keywordMap findif {(_x select 0) == _this};

    if (_index != -1) then {
        (sqfpp_keywordMap select _index) select 1
    };
};

sqfpp_keywordModifiers = ["var"];



sqfpp_tokenToNodeMap = [
    [".",  "class_access"],

    ["=",  "assignment"],
    ["+=", "assignment"],
    ["-=", "assignment"],
    ["*=", "assignment"],
    ["/=", "assignment"],
    ["%=", "assignment"]
];

sqfpp_fnc_getTokenNodeType = {
    private _index = sqfpp_tokenToNodeMap findif {(_x select 0) == _this};

    if (_index != -1) then {
        (sqfpp_tokenToNodeMap select _index) select 1
    };
};



sqfpp_fnc_lex = {
    private _source = _this;

    private _scanner = [_source] call sqfpp_fnc_scannerCreate;

    private _currLine = 1;
    private _currColumn = 1;

    private _tokens = [];

    private "_token";
    while {
        _token = _scanner call sqfpp_fnc_lexerNext;
        (_token select 0) != "end_of_file"
    } do {
        if ((_token select 0) == "ERROR") exitwith {};

        _currColumn = _currColumn + 1;
        _tokens pushback _token;
    };

    _tokens
};


sqfpp_fnc_lexerNext = {
    private _scanner = _this;

    private _char1 = _scanner call sqfpp_fnc_scannerNext;
    private _char2 = [_scanner] call sqfpp_fnc_scannerPeek;

    private _twoCharArray = (toarray _char1) + (toarray _char2);
    private _nextTwoChars = _char1 + _char2;

    scopename "token_categorization";

    // find token type

    // endline

    if (_char1 == sqfpp_endline) then {
        private _line = _currLine;
        private _column = _currColumn;

        _currLine = _currLine + 1;
        _currColumn = 1;

        ["end_line",_char1, [_line,_column]] breakout "token_categorization";
    };

    // whitespace

    if (_char1 == sqfpp_whitespace) then {
        private _whitespace = _char1;

        _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        while {_char1 == sqfpp_whitespace} do {
            _scanner call sqfpp_fnc_scannerNext;
            _whitespace = _whitespace + _char1;
            _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        };

        ["whitespace", _whitespace, [_currLine,_currColumn]] breakout "token_categorization";
    };

    // semicolons

    if (_char1 == ";") then {
        ["semicolon", _char1, [_currLine,_currColumn]] breakout "token_categorization";
    };

    // identifiers
    // bool literals

    if (_char1 in sqfpp_identifierStartChars) then {
        private _identifier = _char1;

        _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        while {_char1 in sqfpp_identifierChars} do {
            _scanner call sqfpp_fnc_scannerNext;
            _identifier = _identifier + _char1;
            _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        };

        // find identifier token type

        private _tokenType = "identifier";
        private _identifierLowercase = tolower _identifier;

        private _operatorInfo = _identifierLowercase call sqfpp_fnc_getOperatorInfo;
        if (!isnil "_operatorInfo") then {
            _tokenType = "operator";
        };

        private _identifierTypeIndex = sqfpp_keywordMap findif {(_x select 1) find _identifierLowercase != -1};
        if (_identifierTypeIndex != -1) then {
            _tokenType = (sqfpp_keywordMap select _identifierTypeIndex) select 0;
        };

        if (_identifierLowercase in sqfpp_keywordModifiers) then {
            _tokenType = "keyword_modifier";
        };

        [_tokenType,_identifier, [_currLine,_currColumn]] breakout "token_categorization";
    };

    // number literals

    if (_char1 in sqfpp_numberStartChars) then {
        private _number = _char1;

        _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        while {_char1 in sqfpp_numberChars} do {
            _scanner call sqfpp_fnc_scannerNext;
            _number = _number + _char1;
            _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        };

        ["number_literal", _number, [_currLine,_currColumn]] breakout "token_categorization";
    };

    // string literals

    private _charNum = (toarray _char1) select 0;
    if (_charNum in sqfpp_stringStartChars) then {
        // remember the quoteChar (single or double quote)
        // so we can look for the same character to terminate the quote

        private _startChar = _char1;
        private _string = _char1;

        _char1 = _scanner call sqfpp_fnc_scannerNext;
        while {_char1 != _startChar} do {
            _string = _string + _char1;
            _char1 = _scanner call sqfpp_fnc_scannerNext;
        };

        _string = _string + _char1; // close quote

        ["string_literal", _string, [_currLine,_currColumn]] breakout "token_categorization";
    };

    // operators

    if (_char1 in sqfpp_operatorChars) then {
        private _operator = _char1;

        _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        while {_char1 in sqfpp_operatorChars} do {
            _scanner call sqfpp_fnc_scannerNext;
            _operator = _operator + _char1;
            _char1 = [_scanner] call sqfpp_fnc_scannerPeek;
        };

        private _operatorInfo = _operator call sqfpp_fnc_getOperatorInfo;
        if (isnil "_operatorInfo") then {
            ["ERROR",_operator, [_currLine,_currColumn]] breakout "token_categorization";
        };

        ["operator",_operator, [_currLine,_currColumn]] breakout "token_categorization";
    };

    if (_char1 in sqfpp_separators) then {
        private _tokenType = switch (_char1) do {
            case ",": { "comma" };
            case ":": { "colon" };
            default { "separator" }
        };

        [_tokenType, _char1, [_currLine,_currColumn]] breakout "token_categorization";
    };

    if (_char1 == "eof") then {
        ["end_of_file","", [_currLine,_currColumn]] breakout "token_categorization";
    };

    // default

    ["Lexer","Unkown character found: %1", [_char1]] call sqfpp_fnc_error;

    ["ERROR", _char1, [_currLine,_currColumn]]
};