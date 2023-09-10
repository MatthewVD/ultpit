**THIS REPOSITORY IS SUPERCEDED BY:** github.com/Mineflowcsm/mineflow



ULTPIT
======
Ultpit is a command line utility to calculate the ultimate pit for open pit mining
operations. Currently the Lerchs and Grossmann algorithm is implemented.

Usage
======

Create a file of the regular block model ordered by x, y, z, realization. That is, the
lowest x, lowest y, lowest z block is the first block in the file, and then it cycles
fastest x, then y, then z, then realization. Currently, this must be pre-calculated
economic block values. Ensure there are both positive and negative blocks. Air has an
economic block value of 0.

To obtain the default parameter file run:

    ultpit --params > params.json

Modify the parameters to be appropriate. Here is an example parameter file:

    {
      "input" : {
        "type" : 1,
        "grid" : {
          "num_x": 60, "min_x": 800.0, "siz_x": 20.0,
          "num_y": 60, "min_y": 100.0, "siz_y": 20.0,
          "num_z": 13, "min_z": 100.0, "siz_z": 20.0 
        }
      },

      "precedence" : {
        "method" : 1,

        "slope" : 45.0,
        "num_benches": 8
      },

      "optimization" : {
        "engine" : 1
      }
    }

Run ultpit:

    ultpit params.json --input data.txt.gz --output optimized.txt

You will get, as output, a file with the same number of rows as your input data with zeros
and ones. A zero indicates that the block should not be mined, and a one indicates that
the block should be mined.

Compilation
===========

    dub --arch=x86_64

Roadmap
========

* Implement an interface to dimacs style programs
* Implement more precedence methods
* Implement the pseudoflow algorithm
* Clean up code 
* 100% code coverage with unit tests

Contact
========

* E-mail -- matthewvdeutsch@gmail.com

License
=======

Ultpit is licensed under the MIT license. See the LICENSE file for details
