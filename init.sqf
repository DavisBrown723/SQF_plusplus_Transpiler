call compile preprocessFileLineNumbers "scanner.sqf";
call compile preprocessFileLineNumbers "lexer.sqf";
call compile preprocessFileLineNumbers "parser.sqf";
call compile preprocessFileLineNumbers "code_transformer.sqf";
call compile preprocessFileLineNumbers "code_generator.sqf";
call compile preprocessFileLineNumbers "soop.sqf";


sqfpp_fnc_error = {
    params ["_component","_message","_messageParameters"];

    private _messageHeader = format ["SQF++: %1 | Error - ", _component];
    private _fullMessage = _messageHeader + _message;
    private _messageData = [_fullMessage] + _messageParameters;

    _messageData call BIS_fnc_error;
    diag_log format _messageData;
};

sqfpp_sqfCommandsByType = call {
    private _info = supportInfo "";
    private _scriptClasses = (_info select {_x select [0,1] == "t"}) apply {_x select [2]};
    private _nular =  (_info select {_x select [0,1] == "n"}) apply {_x select [2]};
    private _unary =  (_info select {_x select [0,1] == "u"}) apply {_x select [2]};
    private _binary = (_info select {_x select [0,1] == "b"}) apply {_x select [2]};

    private _commandsByType = [_nular,_unary,_binary];
    private _commandsByTypeParsed = [];

    {
        private _typeCommands = [];

        {
            _typeCommands pushbackunique (((_x splitstring " ,") select {!(_x in _scriptClasses)}) joinstring "");
        } foreach _x;

        _commandsByTypeParsed pushback _typeCommands;
    } foreach _commandsByType;

    _commandsByTypeParsed
};

// helper functions

sqfpp_fnc_forceUnscheduled = {
    private "_result";
    isnil { _result = call _this };

    _result
};


tokens = (preprocessFile "source.sqf++") call sqfpp_fnc_lex;
//parsed = "source.sqf++" call sqfpp_fnc_parse;
translated = ["source.sqf++", false] call sqfpp_fnc_compileFile;