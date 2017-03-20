/*******************************************************************************
    Ultpit engine

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.engine;

import ultpit.precedence;
import ultpit.logger;
import ultpit.parameters;
import ultpit.lg3d;
import ultpit.dimacs;
import ultpit.util;

import std.json;
import std.stdio;

enum OptimizationEngine {
    LERCHSGROSSMANN = 1,
    DIMACSPROGRAM
}

interface UltpitEngine {
    void initializeFromJSON(in JSONValue json);

    int computeSolution(in double[] data, in Precedence pre,
            out bool[] solution, Logger* = null);
}

UltpitEngine getEngine(in JSONValue json) {
    checkJSONForRequired(json, ["engine"]);
    OptimizationEngine engineType = parseJSONEnum!OptimizationEngine(json["engine"]);

    UltpitEngine engine;
    switch (engineType) {
        case OptimizationEngine.LERCHSGROSSMANN:
            engine = new LG3D();
            break;
        case OptimizationEngine.DIMACSPROGRAM:
            engine = new DimacsSolver();
            break;
        default:
            throw new Exception("Invalid engine type");
    }

    engine.initializeFromJSON(json);
    return engine;
}
