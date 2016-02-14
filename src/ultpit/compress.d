/*******************************************************************************
    Ultpit compression

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.compress;

import ultpit.precedence;
import ultpit.logger;
import ultpit.data;

import std.stdio;
import std.algorithm;
import std.conv;

bool compressEverything(in bool[] mask, in Data data, 
        in Precedence precedence, out Data condensedEBV, 
        out Precedence condensedPre, Logger* logger = null)
{
    ulong count = count!("a")(mask);
    if (logger) {
        logger.writefln("Original: %s", mask.length);
        logger.writefln("Compressed: %s", count);
        logger.writefln("Percent Reduction: %s", (to!double(mask.length - count) /
                    to!double(mask.length)) * 100.0);
    }

    if (!compressData(mask, data, count, condensedEBV)) {
        return false;
    }

    if (!compressPrecedence(mask, count, precedence, condensedPre)) {
        return false;
    }
    if (logger) {
        condensedPre.logExtraInfo(logger);
    }

    return true;
}

bool compressData(in bool[] mask, in Data data, 
        ulong count, out Data condensedEBV)
{
    auto nReal = data.ebv.length;
    condensedEBV.ebv = new double[][](nReal, count);

    ulong j;
    foreach (i; 0 .. mask.length) {
        if (mask[i]) {
            foreach (r; 0 .. nReal) {
                condensedEBV.ebv[r][j] = data.ebv[r][i];
            }
            j++;
        }
    }

    return true;
}

bool compressPrecedence(in bool[] mask, ulong count, in Precedence pre, 
        out Precedence condensedPre)
{
    auto zeroesBefore = new int[](pre.keys.length);
    condensedPre.keys.length = count;

    int currentZeroes;
    int currentKey;
    ulong j = count-1;

    for(long i = to!long(pre.keys.length - 1); i >= 0; i--) {
        if (mask[i]) {
            if (pre.keys[i] != -1) {
                int[] thisNewDef;
                foreach (int off; pre.defs[pre.keys[i]]) {
                    if (mask[i + off]) {
                        auto offZeroes = zeroesBefore[i + off];
                        thisNewDef ~= off-currentZeroes+offZeroes;
                    }
                }
                if (thisNewDef.length != 0) {
                    if (condensedPre.defs.length == 0) {
                        condensedPre.defs ~= thisNewDef;
                    }
                    if (condensedPre.defs[currentKey][] != thisNewDef[]) {
                        condensedPre.defs ~= thisNewDef;
                        currentKey++;
                    }
                    condensedPre.keys[j] = currentKey;
                } else {
                    condensedPre.keys[j] = -1;
                }
            } else {
                condensedPre.keys[j] = -1;
            }
            j--;
        } else {
            currentZeroes++;
        }
        zeroesBefore[i] = currentZeroes;
    }

    return true;
}
