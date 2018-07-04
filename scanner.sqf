scannerCreate = {
    params ["_source"];

    _source = preprocessFile _source;

    private _sourceByChar = _source splitstring "";
    private _sourceSize = count _source;

    [_sourceByChar,_sourceSize,0];
};

scannerPeek = {
    params ["_scanner",["_distance",1]];

    _scanner params ["_chars","_charCount","_nextCharIndex"];

    private _peekIndex = _nextCharIndex + (_distance - 1);

    if (_peekIndex < _charCount) then {
        _chars select _peekIndex
    } else {
        "eof"
    };
};

scannerNext = {
    private _scanner = _this;

    _scanner params ["_chars","_charCount","_nextCharIndex"];

    if (_nextCharIndex < _charCount) then {
        _scanner set [2, _nextCharIndex + 1];

        _chars select _nextCharIndex
    } else {
        "eof"
    };
};

stringToNum = { (toarray _this) select 0 };