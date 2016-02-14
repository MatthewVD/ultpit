/*******************************************************************************
    Ultpit command line executable

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.commandline;

import ultpit.logger;
import ultpit.util;
import ultpit.parameters;
import ultpit.optimization;
import ultpit.program_;

import std.stdio;
import std.getopt;
import std.format;
import std.array;
import std.json;
import std.file;
import std.string;
import std.exception;
import std.algorithm;
import std.conv;

/*******************************************************************************
    Main function for ultpit

    Params: 
        args = the command line arguments
    Returns:
        0 on success, non-zero on failure
*/
int runUltpitCommandLine(string[] args) {
    Options options;
    if (!options.initializeFromArguments(args)) {
        writeln(options.getHelpMessage());
        return 1;
    }
    if (options.showHelp) {
        writeln(options.getHelpMessage());
        return 0;
    }
    if (options.showVersion) {
        writeln(PROGRAM_NAME ~ " " ~ PROGRAM_VERSION);
        return 0;
    }
    if (options.showParams) {
        writeln(getDefaultParameters());
        return 0;
    }

    if (!exists(options.parameterFile)) {
        stderr.writeln("ERROR: parameter file " ~ options.parameterFile ~ " does not exist");
        return 1;
    }
    string contents = readText(options.parameterFile);
    JSONValue json;
    try {
        json = parseJSONWithComments(contents);
    } catch (Exception e) {
        stderr.writeln("ERROR: could not parse json file");
        stderr.writeln(e.msg);
        return 1;
    }

    Logger logger;
    if (options.logFile != "") {
        logger.output = File(options.logFile, "w");
    } else {
        logger.output = stderr;
    }

    logger.log(PROGRAM_NAME ~ " begin");
    int result = optimizeFiles(json, options.inputFile, options.outputFile, &logger);
    logger.log(PROGRAM_NAME ~ " finished");
    return result;
}

/*******************************************************************************
    Holds onto the command line arguments
*/
struct Options {
    /***************************************************************************
        Initialize the Options struct from the command line arguments.

        Params:
            args = The command line arguments
        Returns:
            true on success, false on failure
    */
    bool initializeFromArguments(string[] args) {
        try {
            getopt(args, std.getopt.config.passThrough,
                   "help|h", &showHelp, 
                   "version|v", &showVersion,
                   "params|p", &showParams,
                   "log|l", &logFile,
                   "input|i", &inputFile,
                   "output|o", &outputFile);
        } catch (Exception e) {
            return false;
        }

        if (showHelp || showVersion || showParams) {
            return true;
        }

        if (args.length <= 1) {
            return false;
        }
        parameterFile = args[1];

        return true;
    }

    /***************************************************************************
        Returns:
            The help message
    */
    string getHelpMessage() {
        auto writer = appender!string();
        formattedWrite(writer, "%s - %s - %s\n", PROGRAM_NAME, PROGRAM_VERSION, COPYRIGHT);
        formattedWrite(writer, "Usage: %s [options] parameter_file\n", PROGRAM_NAME);
        formattedWrite(writer, "%s options:\n", PROGRAM_NAME);
        formattedWrite(writer, "%s", " -h       --help          Output this help message\n");
        formattedWrite(writer, "%s", " -v       --version       Output the program version\n");
        formattedWrite(writer, "%s", " -p       --params        Output the default parameters\n");
        formattedWrite(writer, "%s", " -l<file> --log <file>    Log information to a file\n");
        formattedWrite(writer, "%s", " -i<file> --input <file>  The input file\n");
        formattedWrite(writer, "%s", " -o<file> --output <file> The output file\n");

        return writer.data;
    }

    bool showHelp, showVersion, showParams;
    string parameterFile, logFile, inputFile, outputFile;
}
unittest {
    Options options1;
    assert(options1.initializeFromArguments(["ultpit", "--help"]));
    assert(options1.showHelp);

    Options options2;
    assert(options2.initializeFromArguments(["ultpit", "--version"]));
    assert(options2.showVersion);

    Options options3;
    assert(!options3.initializeFromArguments([]));
    assert(!options3.initializeFromArguments(["ultpit"]));

    Options options4;
    assert(options4.initializeFromArguments(["ultpit", "params.json"]));
}


