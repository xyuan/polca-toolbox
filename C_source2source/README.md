The C source to source transformation tool
==========================================

The **C source to source transformation tool** is a program transformation
environment, implemented in [Haskell](https://www.haskell.org/), where architecture-agnostic
scientific C code with semantic annotations is transformed into
functionally equivalent code better suited for a given platform.  The
transformation steps are represented as rules which can be fired when
certain syntactic and semantic conditions are fulfilled.  These rules
are not hard-wired into the rewriting engine: they are written in a
C-like language (STML) and are automatically processed and incorporated by
the rewriting engine.  That makes it possible for end-users to add
their own rules or to provide sets of rules which are adapted to
certain specific domains or purposes.

The C source transformation toolchain has been contributed by the
[IMDEA SW Institute](http://software.imdea.org/es/) and the [Technical University of Madrid](http://www.upm.es/internacional).

Installation
------------

You need the following software and libraries in order to be able to
run the tool: 

| Software        | Description           | URL  |
| ------------- |:-------------:| -----:|
| GHC      | The Glasgow Haskell Compiler.  | https://www.haskell.org/ghc/ |
| GCC      | GNU Compiler Collection      |   https://gcc.gnu.org/ |
| Cabal   | Common Architecture for Building Applications and Libraries | https://www.haskell.org/cabal/ |
| JDK | Java Development Kit (used by Cetus).      |    http://www.oracle.com/technetwork/java/javase/downloads/index.html |
| Antlr | ANother Tool for Language Recognition (used by Cetus).      |    http://www.antlr.org/ |
| Alex | Alex is a tool for generating lexical analysers in Haskell.      |    https://hackage.haskell.org/package/alex |
| Happy | The Haskell Parser Generator.       |    http://hackage.haskell.org/package/happy |
| Meld | [Optional] Meld is a visual diff and merge tool targeted at developers     |    http://meldmerge.org/ |


Getting Started
---------------

The first step is to install all the needed Haskell libraries and
Cetus, a program transformation environment that our tool uses to
annotate the code with some properties. All this is done by running
the command:

```
$ make configure
...
$
```

Before to start transforming your C code, you need to create a Haskell
module named Rules.hs that contains all the STML rules translated
into Haskell.  The transformation tool does that by reading the rules
in STML syntax and translating them into Haskell code, but it is at
the moment not done automatically.  All is needed is a file where the
STML rules are written. A set of rules is provided in the file rules.c
so we can use them as starting point or build a new file with a subset
of them. For instance, if we choose the first option we can build our
Rules.hs file by using:

```
$ make rules FILE=rules.c
[1 of 4] Compiling RulesLib         ( RulesLib.hs, RulesLib.o )
[2 of 4] Compiling PragmaPolcaLib   ( PragmaPolcaLib.hs, PragmaPolcaLib.o )
[3 of 4] Compiling Rul2Has          ( Rul2Has.hs, Rul2Has.o )
[4 of 4] Compiling CompileRules     ( CompileRules.hs, CompileRules.o )
Linking stml2has ...
./stml2has rules.c
AST successfully read from rules.c and stored in rules.ast
Pragmas polca successfully read from rules.c
Rules read:
**************
remove_identity
reduce_to_0
undo_distributive
sub_to_mult
normalize_iteration_step
loop_reversal_d2i
loop_reversal_i2d
loop_interchange
loop_interchange_pragma
for_chunk
unrolling
move_inside_for
collapse_2_for_loops
for_loop_fission
for_loop_fusion_pragma
for_loop_fusion
for_wo_block_2_for_w_block
remove_empty_for
for_to_while
while_to_for
if_wo_block_2_if_w_block
if_wo_else_2_if_w_else
split_addition_assign
join_addition_assign
mult_ternary_2_ternary
sum_ternary_2_ternary
assign_ternary_2_if_else
if_else_2_assign_ternary
if_2_assign_ternary
empty_else
remove_ternary
remove_block
remove_empty_if
remove_useless_statement
strength_reduction
useless_assign
replace_var_equal
just_one_iteration_removemal
join_assignments
propagate_assignment
loop_inv_code_motion
inlining
common_subexp_elimination
introduce_aux_array
flatten_float_array
flatten_int_array
subs_struct_by_fields
roll_up_init
roll_up
roll_up_array_init
roll_up_array
**************

Rules.hs created.
$
```


If you want to create your own rules, just create a new file and write
down them there.  A guide of the functions provided by the (current)
rule language follows:


```
GENERATE

subs((S|[S]|E),E_F,E_T) -> 
    Replace each occurrence of E_F in (S|[S]|E) to E_T;
if_then(Cond,(S|[S]|E)) -> 
    If Cond, then it is possible to generate (S|[S]|E);
if_then_else(Cond,(ST|[ST]|ET),(SE|[SE]|EE)) -> 
    If Cond, then it is possible to generate (ST|[ST]|ET), else (SE|[SE]|EE)
    is generated;
gen_list([S]) ->
    Each statement in [S] produce a different rule consequent.


PATTERN & GENERATE

bin_oper(Op,E_L,E_R) -> 
    Match/generate an operation (E_L Op E_R);


CONDITIONS

is_identity(Op,E) -> 
    True if the given expression is the identity of Op;
no_writes(E_V,(S|[S]|E)) -> 
    True if there is not any assignment to E_V in (S|[S]|E);
no_writes((S|[S]|E)) -> 
    True if there is not any assignment in (S|[S]|E);
no_reads(E_V,(S|[S]|E)) -> 
    True if there is not any use of E_V in (S|[S]|E);
no_rw(E_V,(S|[S]|E)) ->
    True if E_V is not read or write in (S|[S]|E);
is_const(E) -> 
    True if there is not any variable inside E;
is_block(S) ->
    True if the given statement is a block of statements.
not(Cond) -> 
    True if Cond is False;
```


Transforming Your Code
----------------------

When the Rules.hs file has been created starting from the desired
STML rule file, you can compile the main module of the tool:

```
$ make 
ghc -main-is Compilable Compilable.hs -o polca_s2s
[1 of 6] Compiling RulesLib         ( RulesLib.hs, RulesLib.o )
[2 of 6] Compiling PragmaPolcaLib   ( PragmaPolcaLib.hs, PragmaPolcaLib.o )
[3 of 6] Compiling Rules            ( Rules.hs, Rules.o )
[4 of 6] Compiling Translator       ( Translator.hs, Translator.o )
[5 of 6] Compiling Main             ( Main.hs, Main.o )
[6 of 6] Compiling Compilable       ( Compilable.hs, Compilable.o )
Linking polca_s2s ...
$
```

The system now is ready to transform a given C code.  

There are currently three ways of obtaining translated code: randomly, interactively or oracle-based.  Random generation does that: from all the possible
rules and program points where they can be applied, a random selection
is made.  Since the rules are selected without any real goal and some
rules are as of now unsound, the result of this random application is
not really useful except as a randomized test to check that things are
non completely broken.  

The interactive interface of the tool can fire a number of steps
randomly, but at the moment it is intended to be used step-by-step
instead, showing the snippets of code where a transformation can be
aplied, the rules which apply to these code fragments, and waiting for
human feedback to apply the the rule or to skip to the next
transformation.

The interactive session is started by running the created executable,
which receive as argument the target C file:


```
$ ./polca_s2s vec_mult.c
Annotating the code using Cetus...
AST successfully read from vec_mult.c and stored in vec_mult.ast
Pragmas polca successfully read from vec_mult.c
STML Annotated code stored in vec_mult.cetus.cetus.c
AST successfully read from vec_mult.cetus.cetus.c and stored in vec_mult.cetus.cetus.ast
Pragmas polca successfully read from vec_mult.cetus.cetus.c
What rule do you want to apply
1.- loop_reversal_i2d
2.- for_chunk
3.- unrolling
4.- for_loop_fusion_mapmap
5.- for_to_while
6.- propagate_assignment
7.- loop_inv_code_motion
8.- split_addition_assign

? [1/2/3/4/5/6/7/8/h/r/s/c/ec/dc/p/f]: h
-----------------------------------------------------------------
Polca S2S Tool help.
-----------------------------------------------------------------
Select one numerical option to apply the corresponding rule.
The rest of available options are:
h -> This help
r -> Perform a number of random transformation steps
p -> Print current code in a file
s -> Show current code
c -> Show current code without annotations
ec -> Show transformation steps without annotations
dc -> Show transformation steps with annotations (default option)
f -> Finalise transformation session
-----------------------------------------------------------------

Press ENTER to continue...
```

After selecting one of the rule numbers, the tool would show the
effects of applying one of them and wait for confirmation to commit
the transformation, or discard applying the rle.

Let us assume the user wants to apply rule number 4.

```
? [1/2/3/4/5/6/7/8/h/r/s/c/ec/dc/p/f]: 4
Do you want to apply rule for_loop_fusion_mapmap to this piece of code:

    int c[10], v[10], a, b, i;
    int _ret_val_0;
    a = 10;
    b = 10;
    for (i = 0; i < 10; i++)
    {
        c[i] = a * v[i];
    }
    for (i = 0; i < 10; i++)
    {
        c[i] += b * v[i];
    }
    _ret_val_0 = 0;
    return _ret_val_0;


resulting in this new code:

    int c[10], v[10], a, b, i;
    int _ret_val_0;
    a = 10;
    b = 10;
    i = 0 < 10 ? 10 : 0;
    for (i = 0; i < 10; i)
    {
        c[i] = a * v[i];
        c[i] += b * v[i];
    }
    _ret_val_0 = 0;
    return _ret_val_0;
```

The user can accept the transformation or not (returning to previous
question). He/she can also to stop the rule application or finish the
transformation process.

```
? [y/n/a/c/d/v/s/h/f]: h
---------------------------------------------------------------
Polca S2S Tool help.
---------------------------------------------------------------
Available options are:
y -> Apply the transformation step
n -> Omit the transformation step
a -> Show with annotations
c -> Show without annotations
d -> Show only the differences
v -> Open Meld to see the differences
s -> Stop rule application
h -> This help
f -> Finalise transformation session
---------------------------------------------------------------

Press ENTER to continue...
```

If accepted, a new question is shown with the currently
applicable rules.

```
? [y/n/a/c/d/v/s/h/f]: y
7
What rule do you want to apply
1.- unrolling
2.- assign_ternary_2_if_else
3.- propagate_assignment
4.- loop_inv_code_motion
5.- split_addition_assign
6.- remove_ternary

? [1/2/3/4/5/6/h/r/s/c/ec/dc/p/f]: 
```

The fifth transformation can improve the previous code.

```
? [1/2/3/4/5/6/h/r/s/c/ec/dc/p/f]: 5
Do you want to apply rule split_addition_assign to this piece of code:

c[i] += b * v[i]

resulting in this new code:

c[i] = c[i] + b * v[i]

? [y/n/a/c/d/v/s/h/f]: y
What rule do you want to apply
1.- unrolling
2.- assign_ternary_2_if_else
3.- join_assignments
4.- propagate_assignment
5.- loop_inv_code_motion
6.- join_addition_assign
7.- remove_ternary

? [1/2/3/4/5/6/7/h/r/s/c/ec/dc/p/f]: 3
Do you want to apply rule join_assignments to this piece of code:

    c[i] = a * v[i];
    c[i] = c[i] + b * v[i];


resulting in this new code:

    c[i] = a * v[i] + b * v[i];


? [y/n/a/c/d/v/s/h/f]: y
What rule do you want to apply
1.- unrolling
2.- assign_ternary_2_if_else
3.- propagate_assignment
4.- undo_distributive
5.- remove_ternary

? [1/2/3/4/5/h/r/s/c/ec/dc/p/f]: 4
Do you want to apply rule undo_distributive to this piece of code:

a * v[i] + b * v[i]

resulting in this new code:

v[i] * (a + b)

? [y/n/a/c/d/v/s/h/f]: y
What rule do you want to apply
1.- unrolling
2.- assign_ternary_2_if_else
3.- propagate_assignment
4.- loop_inv_code_motion
5.- remove_ternary

? [1/2/3/4/5/h/r/s/c/ec/dc/p/f]: 4
Do you want to apply rule loop_inv_code_motion to this piece of code:

    int c[10], v[10], a, b, i;
    int _ret_val_0;
    a = 10;
    b = 10;
    i = 0 < 10 ? 10 : 0;
    for (i = 0; i < 10; i)
    {
        c[i] = v[i] * (a + b);
    }
    _ret_val_0 = 0;
    return _ret_val_0;


resulting in this new code:

    int c[10], v[10], a, b, i;
    int _ret_val_0;
    a = 10;
    b = 10;
    i = 0 < 10 ? 10 : 0;
    int polca_var_k_0;
    polca_var_k_0 = a + b;
    for (i = 0; i < 10; i)
    {
        c[i] = v[i] * polca_var_k_0;
    }
    _ret_val_0 = 0;
    return _ret_val_0;


? [y/n/a/c/d/v/s/h/f]: y
What rule do you want to apply
1.- unrolling
2.- assign_ternary_2_if_else
3.- propagate_assignment
4.- loop_inv_code_motion
5.- remove_ternary

? [1/2/3/4/5/h/r/s/c/ec/dc/p/f]: f
```

After deciding to finalize the transformation process, the user
has to choose the output platform.

```
To what platform do you want to generate current code:
1.- opencl
2.- mpi
3.- omp
4.- maxj
5.- plain c (with all anotations)
6.- plain c (without STML annotations)
7.- plain c (without any annotation)
8.- go back to transformation
9.- none

? [1/2/3/4/5/6/7/8/9]: 1
Transformed opencl code stored in vec_mult_opencl.c
$
```

Note that the resulting code is stored in a file called as the
original but with selected platform as suffix.

The oracle-based mode works completely automatic using and oracle which in our case is a command. Therefore, it needs as an input a support command that reads JSON expressions and returns the transformation step that should be applied. The usage of this tool is as following:

```
$ make exe_ext
...
$ ./polca_s2s_ext 
Usage:
          polca_s2s_ext command filename [polca_block]
The command and the source file are needed.
The name of a defined block is optional.
```

For instance, if one wants to run an oracle-based session using the [Machine Learning module](https://github.com/polca-project/polca-toolbox/tree/master/Machine%20learning%20component), the following command should be used:

```
$ ./polca_s2s_ext "../Machine learning component/static_analyser/s2s_ml_interface.py" vec_mult.c
...
```


In case of doubt or for further information, please do not hesitate to
contact us.

License and Autorship
---------------------

[License](./LICENSE.txt)

[Authors](./AUTHORS.txt)

Error Reports
-------------

If you think you found a genuine bug please report it together
with the following information:

  - a short test file showing the behavior with all unnecessary
    code removed.

  - a transcript (log file) of the session that shows the error.

Please note that it is important to make the file as small as possible
to allow us to find and fix the error soon.

Original author Salvador Tamarit
Correspondence e-mail: <polca-project-madrid@software.imdea.org>

Please send error reports for contributed files to the original authors.