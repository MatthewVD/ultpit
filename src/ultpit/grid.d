/*******************************************************************************
    This grid class contains a standard grid /definition/ and provides a number of
    utility functions and routines for working with the grid definition, it does
    not contain the actual grid data

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.grid;

import ultpit.util;

import std.conv;
import std.stdio;
import std.string;
import std.file;
import std.json;
import std.exception;
import std.typecons;

class Grid {
    int num_x, num_y, num_z;
    double min_x, min_y, min_z;
    double siz_x, siz_y, siz_z;

    /**
     * This constructor uses all 9 values to initialize the grid.
     * Params:
     *  num_x = Number of blocks in x direction
     *  min_x = Lower left corner of lower left block x coordinate
     *  siz_x = Size of block in x dimension
     *  num_y = Number of blocks in y direction
     *  min_y = Lower left corner of lower left block y coordinate
     *  siz_y = Size of block in y dimension
     *  num_z = Number of blocks in z direction
     *  min_z = Lower left corner of lower left block z coordinate
     *  siz_z = Size of block in z dimension
     */
    this(int num_x, double min_x, double siz_x, 
         int num_y, double min_y, double siz_y, 
         int num_z, double min_z, double siz_z) { 
        this.num_x = num_x;
        this.min_x = min_x;
        this.siz_x = siz_x;
        this.num_y = num_y;
        this.min_y = min_y;
        this.siz_y = siz_y;
        this.num_z = num_z;
        this.min_z = min_z;
        this.siz_z = siz_z;
    }

    /**
     * This constructor takes a json object with all 9 values to initialize the
     * grid.
     * Params:
     *  j = the json object
     *  gslib = True if the json is in gslib format, meaning the mins are not
     *          real mins
     * Throws:
     *  Exception if the json object is not good enough.
     */
    this(in JSONValue j, Flag!"gslibFormat" gslib) {
        auto required = ["num_x", "num_y", "num_z", "min_x", "min_y", "min_z", "siz_x", "siz_y", "siz_z"];
        checkJSONForRequired(j, required, "Grid");

        num_x = parseJSONNumber!int(j["num_x"]);
        num_y = parseJSONNumber!int(j["num_y"]);
        num_z = parseJSONNumber!int(j["num_z"]);
        min_x = parseJSONNumber!double(j["min_x"]);
        min_y = parseJSONNumber!double(j["min_y"]);
        min_z = parseJSONNumber!double(j["min_z"]);
        siz_x = parseJSONNumber!double(j["siz_x"]);
        siz_y = parseJSONNumber!double(j["siz_y"]);
        siz_z = parseJSONNumber!double(j["siz_z"]);
        if (gslib) {
            min_x -= siz_x / 2.0;
            min_y -= siz_y / 2.0;
            min_z -= siz_z / 2.0;
        }
    }
    ///
    unittest {
        Grid grid;
        string s = "{ \"num_x\": 60, \"min_x\": 800, \"siz_x\": 20,
                      \"num_y\": 60, \"min_y\": 100, \"siz_y\": 20,
                      \"num_z\": 13, \"min_z\": 100, \"siz_z\": 20 }";
        JSONValue j = parseJSON(s);
        assertNotThrown(grid = new Grid(j, No.gslibFormat));

        string s2 = "{               \"min_x\": 800, \"siz_x\": 20,
                      \"num_y\": 60, \"min_y\": 100, \"siz_y\": 20,
                      \"num_z\": 13, \"min_z\": 100, \"siz_z\": 20 }";
        JSONValue j2 = parseJSON(s2);
        assertThrown(grid = new Grid(j2, No.gslibFormat));
    }

    //The default constructor
    this() {}

    /**
     * Returns: The grid as a jsonvalue
     */
    JSONValue json() {
        JSONValue j = ["num_x": num_x, "min_x": min_x, "siz_x": siz_x,
                       "num_y": num_y, "min_y": min_y, "siz_y": siz_y,
                       "num_z": num_z, "min_z": min_z, "siz_z": siz_z];

        return j;
    }

    /**
     * Params:
     *  k = The one dimensional grid index.
     * Returns: The grid index in the x direction
     */
    final int gridIx(int k) {
        return (k%(num_x*num_y))%num_x;
    }

    /**
     * Params:
     *  k = The one dimensional grid index.
     * Returns: The grid index in the y direction
     */
    final int gridIy(int k) {
        return (k%(num_x*num_y))/num_x;
    }

    /**
     * Params:
     *  k = The one dimensional grid index.
     * Returns: The grid index in the z direction
     */
    final int gridIz(int k) {
        return k / (num_x*num_y);
    }
    ///
    unittest{
        auto g = new Grid(19, 2.5, 5.0, 10, 2.5, 5.0, 9, 402.5, 5.0);
        assert (g.gridIx(g.num_x + 4) == 4);
        assert (g.gridIy(g.num_x + 4) == 1);
        assert (g.gridIy(g.num_z + 4) == 0);
        assert (g.gridIz(g.num_x*g.num_y*g.num_z) == g.num_z);
    }

    /**
     * Params:
     *  ix = The grid index in the x direction
     *  iy = The grid index in the y direction
     *  iz = The grid index in the z direction
     * Returns: The one dimensional grid index.
     */
    final int gridIndex(int ix, int iy, int iz) const {
        return (ix + iy*num_x + iz*num_x*num_y);
    }
    final int gridIndex(int[] ids) const {
        return (ids[0] + ids[1]*num_x + ids[2]*num_x*num_y);
    }
    ///
    unittest{
        auto g = new Grid(19, 2.5, 5.0, 10, 2.5, 5.0, 9, 402.5, 5.0);
        assert (g.gridIndex(0,0,0) == 0);
        assert (g.gridIndex(5,0,0) == 5);
        assert (g.gridIndex(0,1,0) == g.num_x);
    }

    /**
     * Params:
     *  k = The one dimensional grid index.
     *  x = The test point x coordinate
     *  y = The test point y coordinate
     *  z = The test point z coordinate
     * Returns: True if x, y, z is within the block.
     */
    final bool gridPointInCell(int k, double x, double y, double z) {
        double xn = x - ((to!double(gridIx(k)))*siz_x + min_x);
        if (0.0 <= xn && xn < siz_x) {
            double yn = y - ((to!double(gridIy(k)))*siz_y + min_y);
            if (0.0 <= yn && yn < siz_y) {
                double zn = z - ((to!double(gridIz(k)))*siz_z + min_z);
                if (0.0 <= zn && zn < siz_z) {
                    return true;
                }
            }
        }
        return false;
    }
    ///
    unittest{
        auto g = new Grid(19, 0, 5.0, 10, 0, 5.0, 9, 400, 5.0);
        assert(g.gridPointInCell(0, g.min_x, g.min_y, g.min_z) == true);
        assert(g.gridPointInCell(0, 5.1, 2.5, 2.5) == false);
    }

    /// Write the grid definition to standard output.
    override string toString() const {
        return format("  x =%7d %12.1f  %10.1f\n", num_x, min_x, siz_x)~
               format("  y =%7d %12.1f  %10.1f\n", num_y, min_y, siz_y)~
               format("  z =%7d %12.1f  %10.1f", num_z, min_z, siz_z);
    }

    /// The number of blocks
    @property final pure const int gridCount() {
        return num_x * num_y * num_z;
    }

    /// The grid's bounding axis aligned bounding box
    @property final pure const double[6] aabb() {
        double x0 = min_x;
        double y0 = min_y;
        double z0 = min_z;
        double x1 = min_x + num_x*siz_x;
        double y1 = min_y + num_y*siz_y;
        double z1 = min_z + num_z*siz_z;
        return [x0, y0, z0, x1, y1, z1];
    }

    final double[6] blockAABB(int k) {
        double[3] centroid = blockCentroid(k);
        double halfsiz_x = siz_x/2.0;
        double halfsiz_y = siz_y/2.0;
        double halfsiz_z = siz_z/2.0;

        double[6] AABB;

        AABB[0] = centroid[0] - halfsiz_x;
        AABB[1] = centroid[1] - halfsiz_y;
        AABB[2] = centroid[2] - halfsiz_z;
        AABB[3] = centroid[0] + halfsiz_x;
        AABB[4] = centroid[1] + halfsiz_y;
        AABB[5] = centroid[2] + halfsiz_z;

        return AABB;
    }
    final double[6] blockAABB(int i, int j, int k) {
        double[3] centroid = blockCentroid(i, j, k);

        double halfsiz_x = siz_x/2.0;
        double halfsiz_y = siz_y/2.0;
        double halfsiz_z = siz_z/2.0;

        double[6] AABB;

        AABB[0] = centroid[0] - halfsiz_x;
        AABB[1] = centroid[1] - halfsiz_y;
        AABB[2] = centroid[2] - halfsiz_z;
        AABB[3] = centroid[0] + halfsiz_x;
        AABB[4] = centroid[1] + halfsiz_y;
        AABB[5] = centroid[2] + halfsiz_z;

        return AABB;
    }

    /**
     * Params:
     *  k = The one dimensional grid index.
     * Returns: The centroid as [x, y, z]
     */
    final double[3] blockCentroid(int k) {
        double x = gridIx(k)*siz_x + min_x + siz_x / 2;
        double y = gridIy(k)*siz_y + min_y + siz_y / 2;
        double z = gridIz(k)*siz_z + min_z + siz_z / 2;

        return [x, y, z];
    }
    final double[3] blockCentroid(int i, int j, int k) {
        double x = i*siz_x + min_x + siz_x / 2;
        double y = j*siz_y + min_y + siz_y / 2;
        double z = k*siz_z + min_z + siz_z / 2;

        return [x, y, z];
    }

}
///
unittest{
    auto grid1 = new Grid(19, 2.5, 5.0, 10, 2.5, 5.0, 9, 402.5, 5.0);
    assert (grid1.num_x == 19); assert (grid1.min_x ==   2.5); assert (grid1.siz_x == 5.0);
    assert (grid1.num_y == 10); assert (grid1.min_y ==   2.5); assert (grid1.siz_y == 5.0);
    assert (grid1.num_z ==  9); assert (grid1.min_z == 402.5); assert (grid1.siz_z == 5.0);
}
