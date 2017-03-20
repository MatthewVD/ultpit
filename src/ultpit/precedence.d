/*******************************************************************************
    Ultpit precedence

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.precedence;

import ultpit.logger;
import ultpit.grid;
import ultpit.util;
import ultpit.parameters;

import std.stdio;
import std.json;
import std.string;
import std.math;
import std.conv;
import std.algorithm;

immutable int MISSING = -1;

immutable uint MIN_BENCHES = 1;
immutable uint MAX_BENCHES = 15;
immutable double MIN_SLOPE = 10;
immutable double MAX_SLOPE = 80;

enum PrecedenceMethod {
    BENCH = 1
}

struct Precedence {
    int[] keys;
    int[][] defs;

    void initializeFromJSON(in JSONValue json, in Grid grid, 
                            in bool[] mask, Logger* logger = null)
    {
        checkJSONForRequired(json, ["method"]);

        PrecedenceMethod method = parseJSONEnum!PrecedenceMethod(json["method"]);
        switch (method) {
            case PrecedenceMethod.BENCH:
                checkJSONForRequired(json, ["slope", "num_benches"]);
                double slope = parseJSONNumber!double(json["slope"]);
                uint benches = parseJSONNumber!uint(json["num_benches"]);

                genBench(grid, mask, slope, benches, logger);

                break;
            default:
                throw new Exception("Invalid precedence method");
        }

        logExtraInfo(logger);
    }

    void initialize2D(in double[][] ebv)
    {
        int nz = to!int(ebv.length);
        assert(nz > 0);
        int nx = to!int(ebv[0].length);
        assert(nx > 0);

        int z = nx;
        int x = 1;

        defs = [[ z-x, z, z+x],
                [ z, z+x],
                [ z, z-x]];

        keys.length = nx * nz;
        int l;
        foreach (k; 0 .. nz) {
            foreach (i; 0 .. nx) {
                if (i == 0) {
                    keys[l] = 1;
                }
                if (i == (nx - 1)) {
                    keys[l] = 2;
                }
                if (k == (nz - 1)) {
                    keys[l] = MISSING;
                }
                l++;
            }
        }
    }

    void logExtraInfo(Logger* logger) {
        if (logger) {
            uint count;
            foreach (v; keys) {
                if (v != MISSING) {
                    count++;
                }
            }
            logger.writefln("Number of keys: %s", keys.length);
            logger.writefln("  with arcs: %s", count);
            logger.writefln("  without: %s", keys.length - count);
            logger.writefln("Number of different arc templates: %s", defs.length);

            ulong arcCount;
            foreach (v; keys) {
                if (v != MISSING) {
                    arcCount += defs[v].length;
                }
            }
            logger.writefln("Number of uncompressed arcs: %s", arcCount);

            /*
            int[int] histo;
            keys.each!(a => ++histo[a]);

            immutable string myformat = "%12s|%8s";
            logger.writefln(myformat, "N. Blocks", "Arcs");
            foreach (key, count; histo) {
                if (key == MISSING) {
                    logger.writefln(myformat, count, 0);
                } else {
                    logger.writefln(myformat, count, defs[key].length);
                }
            }
            */
        }
    }

    final void genBench(in Grid grid, in bool[] mask,
            in double slope, in uint benches, Logger* logger = null)
    {
        if (benches < MIN_BENCHES || benches > MAX_BENCHES) {
            throw new Exception (format("ERROR: benches must be between %s and s. Supplied: %s", 
                        MIN_BENCHES, MAX_BENCHES, benches));
        }
        if (slope < MIN_SLOPE || slope > MAX_SLOPE) {
            throw new Exception (format("ERROR: slope must be between %s and s. Supplied: %s", 
                        MIN_SLOPE, MAX_SLOPE, slope));
        }
        if (mask.length != grid.gridCount) {
            throw new Exception ("ERROR: mask size does not equal grid size");
        }

        double theta = slope * PI / 180.0;
        double maxVert = to!double(benches) * grid.siz_z;
        double maxRadius = maxVert / tan(theta);

        int xblock = to!int(maxRadius / grid.siz_x);
        int yblock = to!int(maxRadius / grid.siz_y);
        int xblocks = xblock * 2 + 1;
        int yblocks = yblock * 2 + 1;
        int zblocks = to!int(benches);

        int xcenter = xblock;
        int ycenter = yblock;
        if (logger) {
            logger.writeln("Template size in blocks");
            logger.writefln("  x: %s", xblocks);
            logger.writefln("  y: %s", yblocks);
            logger.writefln("  z: %s", zblocks);
        }

        // Generate base template
        auto offTemplate = new bool[][][](zblocks, yblocks, xblocks);
        foreach (z; 0 .. benches) {
            double zloc = to!double(z + 1) * grid.siz_z;
            double rad = zloc / tan(theta);
            double rad2 = rad * rad;

            foreach (y; 0 .. yblocks) {
                double yloc = to!double(y - ycenter) * grid.siz_y;
                double yloc2 = yloc * yloc;
                foreach (x; 0.. xblocks) {
                    double xloc = to!double(x - xcenter) * grid.siz_x;
                    double xloc2 = xloc * xloc;

                    // If the block centroid is within the cirle, set true
                    offTemplate[z][y][x] = xloc2 + yloc2 <= rad2;
                }
            }
        }

        if (logger) {
            uint count = countTemplate(offTemplate);
            logger.writefln("Number of naive arcs in template: %s", count);
        }

        // Remove absolutely unneccesary arcs
        for (int z = (zblocks-1); z > 0; z--) {
            int nz = z - 1;
            for (int y; y < yblocks; y++) {
                for (int x; x < xblocks; x++) {
                    if (offTemplate[nz][y][x]) {
                        offTemplate[z][y][x] = false;
                    }
                }
            }

            offTemplate[z][yblock][xblock] = true;
        }

        if (logger) {
            uint count = countTemplate(offTemplate);
            logger.writefln("  after basic trimming: %s", count);

            /*
            logger.writeln("Offset template");
            foreach (lev; offTemplate) {
                foreach (v; lev) {
                    string row;
                    foreach (w; v) {
                        if (w) {
                            row ~= "#";
                        } else {
                            row ~= " ";
                        }
                    }
                    logger.writeln(row);
                }
                logger.writeln("");
            }
            */
        }

        int[] firstDef;
        int[] ixs, iys, izs;

        foreach (z; 0 .. zblocks) {
            int zl = z + 1;
            foreach (y; 0 .. yblocks) {
                int yl = y - yblock;
                foreach (x; 0 .. xblocks) {
                    int xl = x - xblock;
                    if (offTemplate[z][y][x]) {
                        int n = grid.gridIndex(xl, yl, zl);
                        firstDef ~= n;
                        ixs ~= xl;
                        iys ~= yl;
                        izs ~= zl;
                    }
                }
            }
        }

        addToDefs(firstDef);

        keys.length = grid.gridCount;
        keys[] = MISSING;
        bool[] hit = new bool[](grid.gridCount);

        uint loc;
        foreach (z; 0 .. grid.num_z - 1) {
            foreach (y; 0 .. grid.num_y) {
                foreach (x; 0 .. grid.num_x) {
                    int[] thisDef;

                    bool doThisOne;
                    if (hit[loc]) {
                        doThisOne = true;
                    } else {
                        doThisOne = mask[loc];
                    }

                    if (doThisOne) {
                        foreach (i; 0 .. ixs.length) {
                            auto xl = x + ixs[i];
                            auto yl = y + iys[i];
                            auto zl = z + izs[i];

                            if (xl < 0 || xl > grid.num_x - 1 ||
                                yl < 0 || yl > grid.num_y - 1 ||
                                zl < 0 || zl > grid.num_z - 1) {
                                // outside
                                continue;
                            } else {
                                auto ind = grid.gridIndex(ixs[i], iys[i], izs[i]);
                                thisDef ~= ind;
                                hit[loc + ind] = true;
                            }
                        }
                    }

                    if (thisDef.length != 0) {
                        keys[loc] = addToDefs(thisDef);
                    } else {
                        keys[loc] = MISSING;
                    }
                    loc++;
                }
            }
        }

    }

    // Try to add the given definition to the defs, return the key
    final int addToDefs(int[] thisDef) {
        // Check for duplicates
        for (int i; i<defs.length; i++) {
            if (equal(thisDef, defs[i])) {
                return i;
            }
        }

        // Else add it
        defs ~= thisDef;
        auto ind = to!int(defs.length)-1;
        return ind;
    }

    // count the trues in the template
    uint countTemplate(in bool[][][] temp) {
        uint count;
        foreach (bench; temp) {
            foreach (row; bench) {
                foreach (v; row) {
                    if (v) {
                        count++;
                    }
                }
            }
        }
        return count;
    }

}

