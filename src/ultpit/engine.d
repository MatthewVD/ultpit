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

enum OptimizationEngine {
    LERCHSGROSSMANN = 1,
    DIMACSPROGRAM
}

interface UltpitEngine {
    int computeSolution(in double[] data, in Precedence pre,
            out bool[] solution, in Parameters params, Logger* = null)
    in {
        assert(pre.keys.length == data.length);
    }
    out {
        assert(solution.length == data.length);
    }
}

