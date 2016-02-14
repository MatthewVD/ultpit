/*******************************************************************************
    Ultpit parameters

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.parameters;

import ultpit.grid;
import ultpit.logger;
import ultpit.util;
import ultpit.data;
import ultpit.precedence;

import std.json;
import std.exception;
import std.stdio;


/*******************************************************************************
    Holds onto the parameters for ultpit
*/
struct Parameters {
    JSONValue inputOptions;
    JSONValue precedenceOptions;
    JSONValue optimizationOptions;

    void initializeFromJSON(in JSONValue json) {
        auto required = ["input", "precedence", "optimization"];
        checkJSONForRequired(json, required, "Parameter file");

        inputOptions = json["input"];
        precedenceOptions = json["precedence"];
        optimizationOptions = json["optimization"];
    }
}

/*******************************************************************************
    The default parameters

    Returns:
        The default parameters as a string
*/
string getDefaultParameters() {
    string params =
"{
// input
//   1 (GEOEAS (GSLIB) format grid file. Pre-calculated EBV)
//     grid (The grid definition)
//       min_x, min_y, min_z (The lower left centroid)
//       num_x, num_y, num_z (The number of blocks) 
//       siz_x, siz_y, siz_z (The size of a block)
//     ebv_column (Economic block value column, 1 indexed)
//   2 (GZIP .gz file, only ebv, one column, no header)
//     grid (as above)
\"input\" : {
  \"type\" : 1,

  \"grid\" : {
    \"num_x\": 60, \"min_x\": 810.0, \"siz_x\": 20.0,
    \"num_y\": 60, \"min_y\": 110.0, \"siz_y\": 20.0,
    \"num_z\": 13, \"min_z\": 110.0, \"siz_z\": 20.0 
  },
  \"ebv_column\" : 1
},

// precedence
//   1 (Benches)
//     slope (The slope (in degrees))
//     benches (The number of benches)
\"precedence\" : {
  \"method\" : 1,

  \"slope\" : 45.0,
  \"num_benches\": 8
},

// optimization_engine
//   1 (Lerchs Grossmann)
//   2 (Dimacs program)
//     dimacs_path (Path to engine)
\"optimization\" : {
  \"engine\" : 1
}
}";

    return params;
}
unittest {
    string defaultParams = getDefaultParameters();
    assertNotThrown(parseJSONWithComments(defaultParams));
}
unittest {
    string defaultParams = getDefaultParameters();
    JSONValue json = parseJSONWithComments(defaultParams);
    Parameters params;
    assertNotThrown(params.initializeFromJSON(json));
}
