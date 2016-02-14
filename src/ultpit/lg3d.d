/*******************************************************************************
    Ultpit lg3d

    References:
        @article{lerchs65,
            title={Optimum Design of Open-Pit Mines},
            author={Lerchs, Helmut and Grossmann, Ingo F},
            journal={Canadian Mining and Metallurgical Bulletin},
            volume={58},
            pages={47-54},
            year={1965},
            number={633},
        }

        @phdthesis{bond95,
            title={A Mathematical Analysis of the Lerchs and Grossmann Algorithm and the
                Nested Lerchs and Grossmann Algorithm},
            author={Bond, Gary D},
            school={Colorado School of Mines},
            year={1995},
            pages={235},
        }

    Copyright: 2016 Matthew Deutsch
    License: Subject to the terms of the MIT license
    Authors: Matthew Deutsch
*/
module ultpit.lg3d;

import ultpit.engine;
import ultpit.precedence;
import ultpit.logger;
import ultpit.parameters;

import std.conv;
import std.algorithm;
import std.range;
import std.stdio;

auto immutable PLUS = true;
auto immutable MINUS = false;
auto immutable STRONG = true;
auto immutable WEAK = false;
auto immutable ROOT = -1;
auto immutable NOTHING = -1;

struct LG_Vertex {
    double mass;
    int rootEdge;
    const int[]* myOffs;
    int[] inEdges;
    int[] outEdges;
    bool strength;

    this(const int[]* offs)
    {
        myOffs = offs;
    }

    final addInEdge(in int e) { 
        inEdges ~= e; 
    }
    final addOutEdge(in int e) { 
        outEdges ~= e; 
    }
    final removeInEdge(in int e) {
        inEdges.remove(countUntil(inEdges, e));
        inEdges.length -= 1;
    }
    final removeOutEdge(in int e) {
        outEdges.remove(countUntil(outEdges, e));
        outEdges.length -= 1;
    }
}

struct LG_Edge {
    double mass;
    int source, target;
    bool direction;
}

class LG_Stack(T) {
    T[] items;

    void push(T top) {items ~= top;}

    T pop() {
        if (empty)
            throw new Exception("Empty Stack.");
        auto top = items.back;
        items.popBack();
        return top;
    }

    T peek() {
        if (empty)
            throw new Exception("Empty Stack.");
        auto top = items.back;
        return top;
    }

    @property bool empty() { return items.empty(); }

    Range opSlice(){
        return Range(items);
    }

    struct Range {
        private T[] _items;
        private this(T[] i) {
            _items = i;
        }

        @property bool empty() { return _items.empty(); }

        @property T front() {
            assert(!empty, "Range is empty");
            return _items.back;
        }

        void popFront() {
            assert(!empty, "Range is empty");
            _items.popBack();
        }
    }
}

class LG3D : UltpitEngine {
    LG_Vertex[] V;
    LG_Edge[] E;
    long arcsAdded;
    long countSinceChange;
    ulong count;

    LG_Stack!int strongPlusses;
    LG_Stack!int strongMinuses;

    int computeSolution(in double[] data, in Precedence pre,
            out bool[] solution, in Parameters params, Logger* = null) {
        count = data.length;
        solution.length = count;

        initNormalizedTree(data, pre);
        solve();

        foreach (i; 0 .. count) {
            solution[i] = V[i].strength;
        }
        return 0;
    }

    final void initNormalizedTree(in double[] data, in Precedence pre) {
        V.reserve(count);
        E.length = count;

        strongPlusses = new LG_Stack!int();
        strongMinuses = new LG_Stack!int();

        foreach (i; 0 .. count) {
            if (pre.keys[i] != NOTHING) {
                V ~= LG_Vertex(&pre.defs[pre.keys[i]]);
            } else {
                V ~= LG_Vertex(null);
            }
            V[i].mass = data[i];
            V[i].rootEdge = to!int(i);
            V[i].strength = data[i] > 0;

            E[i].mass = data[i];
            E[i].source = ROOT;
            E[i].target = to!int(i);
            E[i].direction = PLUS;
        }
    }

    final void solve() {
        int xk;
        while(++countSinceChange <= count) {
            if (V[xk].strength) {
                auto xi = checkPrecedence(xk);
                if (xi != -1) {
                    moveTowardFeasibility(xk, xi);
                    arcsAdded++;
                    //writeln(xk, " ", xi);
                }

                if (!strongPlusses.empty) {
                    foreach (int strongPlus; strongPlusses) {
                        swapStrongPlus(strongPlus);
                        strongPlusses.pop();
                    }
                }
                if (!strongMinuses.empty) {
                    foreach (int strongMinus; strongMinuses) {
                        swapStrongMinus(strongMinus);
                        strongMinuses.pop();
                    }
                }
            }

            if (xk == count-1) {
                xk = 0;
                //if (verbose) {
                //    writeln("Arcs Added: ",arcsAdded);
                //    stdout.flush();
                //    arcsAdded = 0;
                //}
            } else { 
                xk++;
            }
        }

    }

    final void moveTowardFeasibility(int xk, int xi) {
        auto xkStack = stackToRoot(xk);
        auto xiStack = stackToRoot(xi);

        auto lowestRootEdge = xkStack.pop();

        auto baseMass = E[lowestRootEdge].mass;
        E[lowestRootEdge].source = xk;
        E[lowestRootEdge].target = xi;
        E[lowestRootEdge].direction = MINUS;
        
        V[xk].rootEdge = lowestRootEdge;
        V[xi].addInEdge(lowestRootEdge);
        // Fix edges along path back to xk
        foreach (int e; xkStack) {
            if (E[e].direction) {
                auto far = E[e].source;
                auto near = E[e].target;
                V[far].removeOutEdge(e);
                V[near].addInEdge(e);

                V[far].rootEdge = e;
            } else {
                auto far = E[e].target;
                auto near = E[e].source;
                V[far].removeInEdge(e);
                V[near].addOutEdge(e);

                V[far].rootEdge = e;
            }

            E[e].direction = !E[e].direction;
            E[e].mass = baseMass - E[e].mass;

            if (isStrong(E[e])) {
                E[e].direction ? strongPlusses.push(e) : strongMinuses.push(e);
            }
        }
        auto newRootEdge = xiStack.peek();
        auto newMass = E[newRootEdge].mass + baseMass;

        // Now update the other chain
        foreach (int e; xiStack) {
            E[e].mass += baseMass;

            if (isStrong(E[e])) {
                E[e].direction ? strongPlusses.push(e) : strongMinuses.push(e);
            }
        }

        if (newMass > 0) {
            activateBranchToxk(newRootEdge, xk);
        } else {
            deactivateBranch(newRootEdge);
        }
        countSinceChange = 0;
    }

    final void activateBranchToxk(int base, int xk) {
        auto nextV = E[base].direction ? E[base].target : E[base].source;
        if (nextV != xk) {
            foreach (edge; V[nextV].outEdges) {
                activateBranchToxk(edge, xk);
            }
            foreach (edge; V[nextV].inEdges) {
                activateBranchToxk(edge, xk);
            }
        }
        V[nextV].strength = true;
    } 

    final void deactivateBranch(int base) {
        auto nextV = E[base].direction ? E[base].target : E[base].source;
        foreach (edge; V[nextV].outEdges) {
            deactivateBranch(edge);
        }
        foreach (edge; V[nextV].inEdges) {
            deactivateBranch(edge);
        }
        V[nextV].strength = false;
    }

    final bool isStrong(in LG_Edge e) pure nothrow {
        if (e.source != ROOT && e.target != ROOT) {
            return (e.mass>0) == (e.direction);
        } else {
            return false;
        }
    }

    final LG_Stack!int stackToRoot(int k) {
        auto stack = new LG_Stack!int();
        int next;
        int current = k;
        do {
            auto edge = V[current].rootEdge;
            next = E[edge].direction ? E[edge].source : E[edge].target;
            stack.push(edge);
            current = next;
        } while(next != ROOT);
        return stack;
    }

    // Given vertex index k, check if it's precedence are within the solution
    final int checkPrecedence(int k) pure nothrow {
        if (V[k].myOffs) {
            foreach (off; *(V[k].myOffs)) {
                if (!V[k+off].strength) {
                    return k+off;
                }
            }
        }
        return -1;
    }

    // Normalize
    final void swapStrongPlus(int e) {
        // Ensure that it is still a strong plus.
        if (!isStrong(E[e])) {
            return;
        }
        int source = E[e].source;
        int target = E[e].target;
        assert(source != ROOT);

        auto thisMass = E[e].mass;

        int next;
        int current = source;
        int last;
        do {
            last = current;
            auto edge = V[current].rootEdge;
            next = E[edge].direction ? E[edge].source : E[edge].target;
            E[edge].mass -=thisMass;
            current = next;
        } while(next != ROOT);

        V[source].removeOutEdge(e);

        E[e].source = ROOT;

        assert(E[V[last].rootEdge].source == ROOT);
        auto baseEdge = V[last].rootEdge;
        auto baseMass = E[baseEdge].mass;

        if ((baseMass) > 0) {
            if (!V[source].strength) {
                activateBranchToxk(e, -1);
            }
        } else {
            if (V[target].strength) {
                deactivateBranch(baseEdge);
            }
        }

    } 
    final void swapStrongMinus(int e) {
        // Ensure that it is still a strong minus.
        if (!isStrong(E[e])) {
            return;
        }
        int source = E[e].source;
        int target = E[e].target;
        assert(source != ROOT);

        auto thisMass = E[e].mass;

        int next;
        int current = target;
        do {
            auto edge = V[current].rootEdge;
            next = E[edge].direction ? E[edge].source : E[edge].target;
            E[edge].mass -=thisMass;
            current = next;
        } while(next != ROOT);

        E[e].direction =  PLUS;
        E[e].target = source;
        E[e].source = ROOT;
    }


}


