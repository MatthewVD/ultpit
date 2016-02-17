/*******************************************************************************
    Ultpit optimization

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.optimization;

import ultpit.logger;
import ultpit.util;
import ultpit.grid;
import ultpit.parameters;
import ultpit.precedence;
import ultpit.engine;
import ultpit.compress;
import ultpit.lg3d;
import ultpit.data;

import std.json;
import std.file;
import std.stdio;
import std.conv;
import std.algorithm;
import std.zlib;
import std.array;

int optimizeFiles(in JSONValue json, in string inputFile, 
                  in string outputFile, Logger* logger = null) {
    if (logger) {
        logger.log("Being parsing parameters");
    }
    Parameters params;
    try {
        params.initializeFromJSON(json);
    } catch (Exception e) {
        stderr.writeln("Error: failed initializing parameters");
        stderr.writeln(e.msg);
        return 1;
    }

    if (logger) {
        logger.log("Begin reading input");
    }
    Data data;
    try {
        data.initializeFromJSON(params.inputOptions, inputFile);
    } catch (Exception e) {
        stderr.writeln("Error: failed initializing data");
        stderr.writeln(e.msg);
        return 1;
    }

    bool[][] selection;
    int result = optimize(params, data, selection, logger);
    if (result != 0) {
        stderr.writeln("ERROR: failed optimizing");
        return result;
    }

    // TODO Fix this
    // write selection to file
    if (endsWith(outputFile, "gz")) {
        auto app = appender!string();
        foreach (realization; selection) {
            foreach (val; realization) {
                if (val) {
                    app.put("1\n");
                } else {
                    app.put("0\n");
                }
            }
        }

        Compress cmp = new Compress(HeaderFormat.gzip);
        const(void)[] buf = cmp.compress(cast(void[])app.data);
        buf ~= cmp.flush();
        std.file.write(outputFile, buf);
    } else {
        File output;
        if (outputFile != "") {
            output = File(outputFile, "w");
        } else {
            output = stdout;
        }
        output.writeln("ultpit output");
        output.writeln("1");
        output.writeln("Pit");
        foreach (realization; selection) {
            foreach (val; realization) {
                if (val) {
                    output.writeln('1');
                } else {
                    output.writeln('0');
                }
            }
        }
    }

    return 0;
}

int optimize(in Parameters params, in Data data, out bool[][]
        selection, Logger* logger = null) {
    // Validate data
    if (data.ebv.length == 0) {
        stderr.writeln("ERROR: no data");
        return 1;
    } else if (data.ebv[0].length == 0) {
        stderr.writeln("ERROR: no values");
        return 1;
    } else if (data.ebv[0].length != data.grid.gridCount) {
        stderr.writeln("ERROR: wrong number of values.");
        stderr.writefln("Values: %s", data.ebv[0].length);
        stderr.writeln("Grid: ");
        stderr.writeln(data.grid);
        stderr.writefln("Count: %s", data.grid.gridCount);
        return 1;
    }
    ulong nReal = data.ebv.length, nData = data.ebv[0].length;

    if (logger) {
        logger.writefln("Number of realizations: %s", data.ebv.length);
        logger.writefln("Number of rows: %s", data.ebv[0].length);
    }

    // Create the naive mask
    if (logger) {
        logger.log("Begin creating naive mask");
    }
    bool[] mask = generateMask(params, data, logger);

    // Create the precedence
    if (logger) {
        logger.log("Begin creating precedence");
    }
    Precedence precedence;
    try {
        precedence.initializeFromJSON(params.precedenceOptions, data.grid, mask, logger);
    } catch (Exception e) {
        stderr.writeln("Error: failed initializing data");
        stderr.writeln(e.msg);
        return 1;
    }

    if (logger) {
        logger.log("Updating mask");
    }
    // Update the mask
    foreach (i; 0 .. nData) {
        if (mask[i]) {
            auto key = precedence.keys[i];
            if (key != MISSING) {
                foreach (off ; precedence.defs[key]) {
                    mask[i + off] = true;
                }
            }
        }
    }

    // Compress everything 
    if (logger) {
        logger.log("Begin compressing");
    }
    Data condensedEBV;
    Precedence condensedPre;
    if (!compressEverything(mask, data, precedence, 
                condensedEBV, condensedPre, logger)) {
        stderr.writeln("ERROR: Compressing everything failed");
        return 1;
    }

    // allocate the condensedSolutions
    bool[][] solutions = new bool[][](condensedEBV.ebv.length,
            condensedEBV.ebv[0].length);

    // Solve-em
    if (logger) {
        logger.log("Begin optimizing");
    }
    foreach (r; 0 .. nReal) {
        UltpitEngine engine;
        try {
            engine = getEngine(params.optimizationOptions);
        } catch (Exception e) {
            stderr.writeln("Error: failed initializing optimization engine");
            stderr.writeln(e.msg);
            return 1;
        }
        engine.computeSolution(condensedEBV.ebv[r], condensedPre, solutions[r]);

        if (logger) {
            double ebv = 0;
            ulong count;
            foreach (i; 0 .. condensedEBV.ebv[r].length) {
                if (solutions[r][i]) {
                    ebv += condensedEBV.ebv[r][i];
                    count++;
                }
            }
            logger.logf("Completed realization %s. Blocks: %s, EBV: %s", r, count, ebv);
        }
    }

    // Expand the solutions out
    if (logger) {
        logger.log("Decompressing solutions");
    }
    selection = new bool[][](nReal, nData);
    ulong j;
    foreach (i; 0 .. nData) {
        if (mask[i]) {
            foreach (r; 0 .. nReal) {
                selection[r][i] = solutions[r][j];
            }
            j++;
        }
    }

    // Fix air blocks
    if (logger) {
        logger.log("Fixing air blocks");
    }
    foreach (r; 0 .. nReal) {
        foreach (i; 0 .. nData) {
            if (selection[r][i]) {
                auto key = precedence.keys[i];
                if (key != MISSING) {
                    foreach (off; precedence.defs[key]) {
                        selection[r][i + off] = true;
                    }
                }
            }
        }
    }

    return 0;
}

bool[] generateMask(in Parameters params, in Data data, Logger* logger = null) {
    uint n = data.grid.gridCount;
    bool[] mask = new bool[](n);

    foreach (i; 0 .. n) {
        foreach (r; 0 .. data.ebv.length) {
            if (data.ebv[r][i] >= 0) {
                mask[i] = true;
                break;
            }
        }
    }

    // Erase from end until first non zero value (removes air)
    uint i = n - 1;
    while (i > 0) {
        bool air = true;
        foreach (r; 0 .. data.ebv.length) {
            if (data.ebv[r][i] != 0) {
                air = false;
                break;
            }
        }

        if (air) {
            mask[i] = false;
        } else {
            break;
        }
        i--;
    }

    if (logger) {
        logger.writefln("Count of values in mask: %s", count!("a")(mask));
    }

    return mask;
}

unittest {
    string inputFile = "ebv.dat";
    string outputFile = "out.dat";
    auto input = File(inputFile, "w");
    auto ebv = [[ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2, 4,-1,-2,-3,-2,-2,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2,-2,-2,20,-2,-2,-2,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2,-2,-2,-2,-2,-2,10,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2],
                [-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2]];
    auto sol = [[ 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]];
    reverse(ebv); reverse(sol);
    int nz = to!int(ebv.length);
    int nx = to!int(ebv[0].length);

    Grid grid = new Grid(nx, 0, 1, 1, 0, 1, nz, 0, 1);
    input.writeln("title");
    input.writeln("1");
    input.writeln("var");
    foreach (j; 0 .. nz) {
        foreach (i; 0 .. nx) {
            input.writeln(ebv[j][i]);
        }
    }
    input.close();
    string params = "{ \"input\" : { \"type\" : 1, \"grid\" : {
    \"num_x\": 15, \"min_x\": 0.5, \"siz_x\": 1.0,
    \"num_y\": 1, \"min_y\": 0.5, \"siz_y\": 1.0,
    \"num_z\": 8, \"min_z\": 0.5, \"siz_z\": 1.0 }, \"ebv_column\": 1 },
    \"precedence\" : { \"method\" : 1, \"slope\" : 45.0, \"num_benches\": 8 }, 
    \"optimization\" : { \"engine\" : 1 } }";

    auto gridJson = grid.json();
    JSONValue json = parseJSON(params);

    //Logger logger;
    //logger.output = stdout;
    //optimizeFiles(json, input, output, &logger);

    auto result = optimizeFiles(json, inputFile, outputFile);
    assert(result == 0);

    // Reuse data class
    Data resultData;
    File output = File(outputFile, "r");
    resultData.initializeFromGSLIB(output, grid, 0);
    ulong k;
    foreach (j; 0 .. nz) {
        foreach (i; 0 .. nx) {
            assert(sol[j][i] == resultData.ebv[0][k]);
            k++;
        }
    }

    remove(inputFile);
    remove(outputFile);
}

