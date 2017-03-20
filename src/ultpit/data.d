/*******************************************************************************
    Ultpit data

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.data;

import ultpit.grid;
import ultpit.util;

import std.stdio;
import std.string;
import std.file;
import std.algorithm;
import std.conv;
import std.zlib;
import std.string;
import std.range;
import std.json;
import std.exception;
import std.typecons;

enum InputFormat {
    GSLIB = 1,
    GZIP
}

struct Data {
    double[][] ebv;
    Grid grid;

    void initializeFromJSON(in JSONValue json, in string inputFile)
    {
        checkJSONForRequired(json, ["type"]);
        InputFormat format = parseJSONEnum!InputFormat(json["type"]);
        switch (format) {
            case InputFormat.GSLIB:
                File input;
                if (inputFile == "") {
                    input = stdin;
                } else {
                    if (!exists(inputFile)) {
                        throw new Exception("Input file " ~ inputFile ~ " does not exist");
                    }
                    input = File(inputFile, "r");
                }

                checkJSONForRequired(json, ["grid", "ebv_column"]);
                grid = new Grid(json["grid"], Yes.gslibFormat);
                uint column = parseJSONNumber!uint(json["ebv_column"]) - 1;

                initializeFromGSLIB(input, grid, column);
                break;
            case InputFormat.GZIP:
                checkJSONForRequired(json, ["grid"]);
                grid = new Grid(json["grid"], Yes.gslibFormat);

                if (!exists(inputFile)) {
                    throw new Exception("Input file " ~ inputFile ~ " does not exist");
                }
                initializeFromGzip(inputFile, grid);
                break;
            default:
                throw new Exception("Invalid input format");
        }
    }

    void initializeFromGSLIB(File input, in Grid gridspec, uint column) {
        ebv = new double[][](1, gridspec.gridCount);

        auto title = input.readln();
        auto strings = split(chomp(input.readln()));
        auto nvar = to!int(strings[0]);

        foreach (i; 0 .. nvar) {
            input.readln();
        }

        auto firstline = to!(char[])(input.readln());
        double[] firstvals;
        bool commaDelimited;
        if (countUntil(firstline, ",") != -1) {
            commaDelimited = true;
            firstvals = parseCSVLine(firstline);
        } else {
            commaDelimited = false;
            firstvals = parseDatLine(firstline);
        }
        if (firstvals.length == 0) {
            throw new Exception("Error in data file");
        }
        if (column > firstvals.length) {
            throw new Exception("Column out of bounds");
        }
        ebv[0][0] = firstvals[column];

        uint k = 0;
        uint i = 1;
        foreach(line; input.byLine) {
            if (i >= gridspec.gridCount) {
                i = 0;
                k++;

                double[] realization = new double[](gridspec.gridCount);
                ebv ~= realization;
            }

            double[] vals;
            if (commaDelimited) {
                vals = parseCSVLine(line);
            } else {
                vals = parseDatLine(line);
            }

            ebv[k][i] = vals[column];

            i++;
        }

        if (i != gridspec.gridCount) {
            throw new Exception("Data is not a multiple of the grid count");
        }
    }

    void initializeFromGzip(string fileName, in Grid gridspec) {
        void[] buf = read(fileName);
        UnCompress decmp = new UnCompress;
        const(void)[] input = decmp.uncompress(buf);
        input ~= decmp.flush();
        char[] data = cast(char[])input;

        ebv = new double[][](1, gridspec.gridCount);
        uint k = 0;
        uint i = 0;
        uint j = 0;
        foreach (line; lineSplitter(data)) {
            if (i >= gridspec.gridCount) {
                i = 0;
                k++;

                double[] realization = new double[](gridspec.gridCount);
                ebv ~= realization;
            }

            ebv[k][i] = to!double(line);
            i++;
            j++;
        }

        if (i != gridspec.gridCount) {
            throw new Exception("Data is not a multiple of the grid count");
        }
    }
}
unittest {
    JSONValue empty;
    Data data;
    assertThrown(data.initializeFromJSON(empty, ""));

    JSONValue badType = ["type": 0];
    assertThrown(data.initializeFromJSON(badType, ""));

    string badOptionString = "{ \"type\" : 1, \"grid\" : {
    \"num_x\": 1, \"min_x\": 10.0, \"siz_x\": 20.0,
    \"num_y\": 1, \"min_y\": 10.0, \"siz_y\": 20.0,
    \"num_z\": 1, \"min_z\": 10.0, \"siz_z\": 20.0 
    }, \"woops\" : 1 }";
    JSONValue badOptions = parseJSON(badOptionString);
    assertThrown(data.initializeFromJSON(badOptions, ""));
}
unittest {
    string jsonString = "{ \"type\" : 1, \"grid\" : {
    \"num_x\": 10, \"min_x\": 10.0, \"siz_x\": 20.0,
    \"num_y\": 10, \"min_y\": 10.0, \"siz_y\": 20.0,
    \"num_z\": 1, \"min_z\": 10.0, \"siz_z\": 20.0 
    }, \"ebv_column\" : 1 }";
    JSONValue json = parseJSON(jsonString);

    string tempName = "temp_fiel";
    auto file = File(tempName, "w");
    file.writeln("Title");
    file.writeln("1");
    file.writeln("EBV");
    foreach (i; 0 .. 100) {
        file.writeln(i);
    }
    file.close();

    Data data;
    assertNotThrown(data.initializeFromJSON(json, tempName));
    foreach (i; 0 .. 100) {
        assert(data.ebv[0][i] == i);
    }
    assert(data.grid.num_x == 10);
    assert(data.grid.num_y == 10);
    assert(data.grid.num_z == 1);

    remove(tempName);
}
unittest {
    string jsonString = "{ \"type\" : 1, \"grid\" : {
    \"num_x\": 10, \"min_x\": 10.0, \"siz_x\": 20.0,
    \"num_y\": 10, \"min_y\": 10.0, \"siz_y\": 20.0,
    \"num_z\": 1, \"min_z\": 10.0, \"siz_z\": 20.0 
    }, \"ebv_column\" : 3 }";
    JSONValue json = parseJSON(jsonString);

    string tempName = "temp_fiel";
    auto file = File(tempName, "w");

    file.writeln("Title");
    file.writeln("  4   stuff");
    file.writeln("Var 1");
    file.writeln("Var 2");
    file.writeln("Var 3");
    file.writeln("Var 4");
    foreach (i; 0 .. 100) {
        file.writefln("  %s,%s,%s,  %s", i, i * 2, i * 3, i * 4);
    }
    file.close();

    Data data;
    assertNotThrown(data.initializeFromJSON(json, tempName));
    foreach (i; 0 .. 100) {
        assert(data.ebv[0][i] == i * 3);
    }

    remove(tempName);
}

