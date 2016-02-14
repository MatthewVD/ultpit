/*******************************************************************************
    Ultpit logger

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.logger;

import std.stdio;
import std.datetime;
import std.conv;
import std.string;

struct Logger {
    void log(string msg) {
        output.write(timeStamp(), " ");
        output.writeln(msg);
    }

    void writeln(string msg) {
        output.writeln(msg);
    }

    void logf(A...)(string format, A a) {
        output.write(timeStamp(), " ");
        output.writefln(format, a);
    }

    void writefln(A...)(string format, A a) {
        output.writefln(format, a);
    }

    string timeStamp() {
        auto currentTime = Clock.currTime();
        return "[" ~ currentTime.toString() ~ "]";
    }

    File output;
}
