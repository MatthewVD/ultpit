3rd
---
An interface to third party dimacs style solvers is provided using optimization engine
number 2. Provide the path to the executable with the "dimacs_path" json option.

[The dimacs format is described here.](http://lpsolve.sourceforge.net/5.5/DIMACS_maxf.htm)

Hochbaum's Pseudoflow
---------------------
The primary executable this interface is provided to satisfy is [Hochbaum's pseudoflow
implementation](http://riot.ieor.berkeley.edu/Applications/Pseudoflow/maxflow.html). I
have not included the code / executable here to respect their license. Note that their
executable may only be used for educational, research, and not-for-profit purposes.

It can generally solve for the ultimate pit several orders of magnitude faster.

If you are using the code for research purposes here are some general instructions to
compile the program correctly, you will have to be on a unix system - however it is not
overly difficult to modify the code for a windows system:

- Download the solver (Version 3.23 at the time of writing)
- Run the following command to extract the tar file
    ```
    tar -xvf pseudo-max-3.23_2.tar
    ```

- Modify the makefile, add '-DDISPLAY_CUT' to the pseudo_fifo target, it should look
  similar to:
    ```
    ${BINDIR}/pseudo_fifo:
        ${CC} ${CFLAGS} -DFIFO_BUCKET -DDISPLAY_CUT src/3.23/pseudo.c -o bin/pseudo_fifo
    ```

- Run the following command to compile
    ```
    make pseudo_fifo
    ```

- Grab the executable out of the bin/ folder

