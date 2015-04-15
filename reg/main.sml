structure Main = struct

    structure Tr = Translate
    structure F = MipsFrame
    structure R = RegAlloc

    fun withOpenFile fname f = 
        let
            val out = TextIO.openOut fname
        in (f out before TextIO.closeOut out) 
            handle e => (TextIO.closeOut out; raise e)
        end 

    fun emitproc out (F.STRING(lab,s)) =
            (
                print ("========== Fragment:  " ^ (S.name lab) ^ " ==========\n");
                TextIO.output(TextIO.stdOut, F.string(lab,s));
                TextIO.output(out, F.string(lab,s))
            )
      | emitproc out (F.PROC{body,frame}) =
            let 
                val format0 = Assem.format(F.makestring)
                fun dummySpillCost x = 1;
                fun printGraphNode (id, node as {def, use, ismove}) =
                    id ^ "(def: " ^ (foldl (fn (temp, str) => str ^ Temp.makestring temp ^ ", ") "" def)
                    ^ " -- use: " ^ (foldl (fn (temp, str) => str ^ Temp.makestring temp ^ ", ") "" use)
                    ^ " -- ismove: " ^ (Bool.toString ismove) ^ ")"

                val stms : Tree.stm list = Canon.linearize body
                val stms' : Tree.stm list = Canon.traceSchedule(Canon.basicBlocks stms)
                val instrs : Assem.instr list = List.concat(map (MipsGen.codegen frame) stms')
                val formattedInstrs : string = foldl (fn (insn, strSoFar) => strSoFar ^ (format0 insn)) "" instrs
                val flowgraph : MakeGraph.graphentry StrKeyGraph.graph = MakeGraph.makeFlowgraph instrs
                val (igraph, _, _) = Liveness.interferenceGraph flowgraph
                val (alloc, spilllist) = Color.color {igraph=igraph, initial=R.initialAlloc, spillCost=dummySpillCost, registers=R.regList}
                val finalAssembly : string = R.performAllocation(formattedInstrs, alloc)
            in 
                (
                    print ("========== Fragment:  " ^ S.name (F.name frame) ^ " ==========\n");
                    print ("=== PRE-CANON " ^ S.name (F.name frame) ^ " ===\n");
                    Printtree.printtree(TextIO.stdOut,body);
                    print ("=== POST-CANON "  ^ S.name (F.name frame) ^ " ===\n");
                    app (fn s => Printtree.printtree(TextIO.stdOut,s)) stms;
                    print ("=== EMIT "  ^ S.name (F.name frame) ^ " ===\n");
                    app (fn i => TextIO.output(TextIO.stdOut,format0 i)) instrs;
                    print ("=== Flowgraph "  ^ S.name (F.name frame) ^ " ===\n");
                    StrKeyGraph.printGraph printGraphNode flowgraph;
                    TextIO.output(out, finalAssembly)
                )
            end

   fun sortFrags frags =
      let
        val revFrags = rev frags
        fun moveStrings([], newList) = newList
          | moveStrings(a::l, newList) =
              case a of
                  F.STRING(lab,s) => a::moveStrings(l, newList)
                | _ => moveStrings(l, newList)
        fun moveProcs([], newList) = newList
          | moveProcs(a::l, newList) =
              case a of
                  F.PROC{body,frame} => a::moveProcs(l, newList)
                | _ => moveProcs(l, newList)
      in
        moveStrings(frags, moveProcs(frags, []))
      end

   fun compile filename = 
        let
            val absyn : Absyn.exp = Parse.parse filename
            val frags : MipsFrame.frag list= sortFrags (FindEscape.findEscape absyn; Semant.transProg absyn)
        in 
            (
                print "================ AST ==================\n";
                PrintAbsyn.print(TextIO.stdOut, absyn);
                print "======== Syntax Errors (if any) ========\n";
                withOpenFile (filename ^ ".s") (fn out => (app (emitproc out) frags))
            )
       end
end
