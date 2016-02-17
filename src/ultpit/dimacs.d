/*******************************************************************************
    Ultpit dimacs interface

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.dimacs;

import ultpit.precedence;
import ultpit.parameters;
import ultpit.engine;
import ultpit.logger;

import std.stdio;
import std.conv;
import std.math;
import std.json;

immutable auto PRECISION = 100.0; 

void writeDimacsFile(in double[] data, in Precedence pre, ref File output) {
    uint numNodes = to!uint(data.length) + 2; // source and sink
    uint numArcs = to!uint(data.length); // source to positive nodes, sink to negative nodes
    foreach (i; 0 .. data.length) {
        auto ind = pre.keys[i];
        // Each infinite arc
        if (ind != MISSING) {
            numArcs += pre.defs[ind].length;
        }
    }

    uint SOURCE = 1;
    uint SINK = numNodes;
    output.writefln("p max %s %s", numNodes, numArcs);
    output.writefln("n %s s", SOURCE);
    output.writefln("n %s t", SINK);

    // add the non-infinite arcs
    ulong from_i, to_i;
    foreach (i; 0 .. data.length) {
        uint capacity = to!uint(abs(data[i]) * PRECISION);
        if (data[i] < 0) {
            from_i = i + 2; // + 1 to get in pseudoflow numbering + 1 for source
            to_i = SINK;
        } else {
            from_i = SOURCE;
            to_i = i + 2; // + 1 for pseudo, +1 for source
        }

        output.writefln("a %s %s %s", from_i, to_i, capacity);
    }

    // Now the infinite ones
    foreach (i; 0 .. data.length) {
        auto ind = pre.keys[i];
        from_i = i + 2; // + 1 for psuedo, +1 for source
        if (ind != MISSING) {
            foreach (off; pre.defs[ind]) {
                output.writefln("a %s %s %s", from_i, from_i + off, uint.max);
            }
        }
    }
}

class DimacsSolver : UltpitEngine {
    void initializeFromJSON(in JSONValue json) {
    }

    int computeSolution(in double[] data, in Precedence pre,
            out bool[] solution, Logger* = null) {
        ulong count = data.length;
        solution.length = count;

        return 0;
    }
}
