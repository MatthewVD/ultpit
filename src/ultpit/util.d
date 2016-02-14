/*******************************************************************************
    Ultipit minor utilities

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.util;

import ultpit.grid;

import std.conv;
import std.json;
import std.array;
import std.string;
import std.stdio;
import std.file;
import std.exception;
import std.algorithm;

/*******************************************************************************
    Parse some json into a number
*/
T parseJSONNumber(T)(in JSONValue j) {
    switch (j.type) {
        case JSON_TYPE.INTEGER:
        case JSON_TYPE.UINTEGER:
            return to!T(j.integer);
        case JSON_TYPE.FLOAT:
            return to!T(j.floating);
        case JSON_TYPE.STRING:
            return to!T(j.str);
        default:
            throw new Exception("Could not parse");
    }
}
unittest {
    string str = "{ \"num\": 12.3 }";
    double v = parseJSONNumber!double(parseJSON(str)["num"]);
    assert(v == 12.3);

    str = "{ \"num\": 12 }";
    v = parseJSONNumber!double(parseJSON(str)["num"]);
    assert(v == 12);

    str = "{ \"num\": \"12.3\" }";
    v = parseJSONNumber!double(parseJSON(str)["num"]);
    assert(v == 12.3);
}

/*******************************************************************************
    Parse some json into an enum
*/
T parseJSONEnum(T)(in JSONValue j) {
    try {
        switch (j.type) {
            case JSON_TYPE.INTEGER:
            case JSON_TYPE.UINTEGER:
                return to!T(j.integer);
            case JSON_TYPE.STRING:
                return to!T(to!int(j.str));
            default:
                throw new Exception("Could not parse");
        }
    } catch (Exception e) {
        throw new Exception("Could not parse");
    }
}
unittest {
    enum options
    {
        A = 1,
        B,
        C
    }

    JSONValue json1 = ["type": 1];
    options option1 = parseJSONEnum!options(json1["type"]);
    assert(option1 == options.A);

    JSONValue json2 = ["type": 2];
    options option2 = parseJSONEnum!options(json2["type"]);
    assert(option2 == options.B);

    JSONValue json3 = ["type": 3];
    options option3 = parseJSONEnum!options(json3["type"]);
    assert(option3 == options.C);

    JSONValue json4 = ["type": "1"];
    options option4 = parseJSONEnum!options(json4["type"]);
    assert(option4 == options.A);

    JSONValue json5 = ["type": "butts"];
    assertThrown(parseJSONEnum!options(json5["type"]));

    JSONValue json6 = ["type": "5"];
    assertThrown(parseJSONEnum!options(json6["type"]));
}

/*******************************************************************************
    Reads the json, strips out the comments
*/
JSONValue parseJSONWithComments(in string contents) {
    auto writer = appender!string();
    string[] lines = splitLines(contents);
    foreach(string line; lines) {
        string left = stripLeft(line);
        if (countUntil(left, "//") != 0) {
            writer ~= line;
        }
    }

    return parseJSON(writer.data);
}

/*******************************************************************************
    Checks a json for required parameters

    Params:
        json = The json value
        required = The list of required fields
    Throws:
        an error message if item is missing
*/
void checkJSONForRequired(in JSONValue json, in string[] required, 
        in string name = "Json") {
    foreach (req; required) {
        if (req !in json.object) {
            auto errormsg = "ERROR: "~name~" could not be parsed, missing \'"~req~"\'";
            throw new Exception(errormsg);
        }
    }
}

double[] parseCSVLine(char[] line) {
    char[][] tempStrings;
    foreach (str; split(line,",")) {
        tempStrings ~= strip(str);
    }

    return to!(double[])(tempStrings);
}
unittest {
    char[] line = to!(char[])("  1.0,2.0, 4.1");
    auto vals = parseCSVLine(line);
    assert(vals[0] == 1.0);
    assert(vals[1] == 2.0);
    assert(vals[2] == 4.1);
}

double[] parseDatLine(char[] line) {
    return to!(double[])(split(line));
}
unittest {
    char[] line = to!(char[])("  1.0  2.0  4.1");
    auto vals = parseDatLine(line);
    assert(vals[0] == 1.0);
    assert(vals[1] == 2.0);
    assert(vals[2] == 4.1);
}
