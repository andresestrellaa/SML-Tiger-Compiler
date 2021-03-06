structure Tr = Tree
structure Err = ErrorMsg

structure MipsFrame : FRAME = 
struct
    type register = string
    datatype access = InFrame of int | InReg of Temp.temp
    type frame = {name: Temp.label, formals: access list,
                  numLocals: int ref, curOffset: int ref}
    datatype frag = PROC of {body: Tree.stm, frame: frame}
                  | STRING of Temp.label * string
                           
    val R0 = Temp.newtemp() (* zero register *)
    val AT = Temp.newtemp() (* assembler temporary, reserved *)

    val RV = Temp.newtemp() (* return value *)
    val V1 = Temp.newtemp()

    val A0 = Temp.newtemp() (* args *)
    val A1 = Temp.newtemp()
    val A2 = Temp.newtemp()
    val A3 = Temp.newtemp()

    val T0 = Temp.newtemp()
    val T1 = Temp.newtemp()
    val T2 = Temp.newtemp()
    val T3 = Temp.newtemp()
    val T4 = Temp.newtemp()
    val T5 = Temp.newtemp()
    val T6 = Temp.newtemp()
    val T7 = Temp.newtemp()

    val S0 = Temp.newtemp()
    val S1 = Temp.newtemp()
    val S2 = Temp.newtemp()
    val S3 = Temp.newtemp()
    val S4 = Temp.newtemp()
    val S5 = Temp.newtemp()
    val S6 = Temp.newtemp()
    val S7 = Temp.newtemp()

    val T8 = Temp.newtemp()
    val T9 = Temp.newtemp()

    val K0 = Temp.newtemp() (* reserved for kernel *)
    val K1 = Temp.newtemp()

    val GP = Temp.newtemp()
    val SP = Temp.newtemp()
    val FP = Temp.newtemp() (* frame pointer *)
    val RA = Temp.newtemp() (* return address *)

    val specialregs = [
        (RV, "$v0"),
        (V1, "$v1"),
        (R0, "$zero"),
        (AT, "$at"), 
        (K0, "$k0"),
        (K1, "$k1"),
        (GP, "$gp"),
        (SP, "$sp"),
        (FP, "$fp"),
        (RA, "$ra")
    ]
    val argregs = [
        (A0, "$a0"),
        (A1, "$a1"),
        (A2, "$a2"),
        (A3, "$a3")
    ]
    val calleesaves = [
        (S0, "$s0"),
        (S1, "$s1"),
        (S2, "$s2"),
        (S3, "$s3"),
        (S4, "$s4"),
        (S5, "$s5"),
        (S6, "$s6"),
        (S7, "$s7")
    ]
    val callersaves = [
        (T0, "$t0"),
        (T1, "$t1"),
        (T2, "$t2"),
        (T3, "$t3"),
        (T4, "$t4"),
        (T5, "$t5"),
        (T6, "$t6"),
        (T7, "$t7"),
        (T8, "$t8"),
        (T9, "$t9")
    ]

    val tempMap = 
        let
            fun addtotable ((t, s), table) = Temp.Table.enter(table, t, s)
            val toadd = specialregs @ argregs @ calleesaves @ callersaves
        in
            foldr addtotable Temp.Table.empty toadd
        end
    fun makestring t = (* replacement for temp.makestring *)
        case Temp.Table.look(tempMap, t) of
             SOME(r) => r
           | NONE => Temp.makestring t
    val wordSize = 4

    fun name {name=name, formals=_, numLocals=_, curOffset=_} = name
    fun formals {name=_, formals=formals, numLocals=_, curOffset=_} = formals
    fun escapeChar #"\n" = "\\n"
      | escapeChar #"\t" = "\\t"
      | escapeChar c = Char.toString c
    fun string(lab, s) = (Symbol.name lab) ^ ":\n .word " ^ Int.toString(String.size(s)) ^ "\n .ascii \"" ^ (String.translate escapeChar s) ^ "\"\n"
    
    val ARGREGS = 4 (* registers allocated for arguments in mips *)
    val STARTOFFSET = ~44 (* 0-40 used for RA and FP and calleesaves *)
    fun newFrame {name, formals} = 
        let
            fun allocFormals(offset, [], allocList, index) = allocList
              | allocFormals(offset, curFormal::l, allocList, index) = 
                  (
                  case curFormal of
                       true => (InFrame offset)::allocFormals(offset + wordSize, l, allocList, index + 1)
                     | false => (InReg(Temp.newtemp()))::allocFormals(offset + wordSize, l, allocList, index + 1)
                  )
        in
            {name=name, formals=allocFormals(0, formals, [], 0),
            numLocals=ref 0, curOffset=ref STARTOFFSET}
        end

    fun allocLocal frame' escape = 
        let
            fun incrementNumLocals {name=_, formals=_, numLocals=x, curOffset=_} = x := !x + 1
            fun incrementOffset {name=_, formals=_, numLocals=_, curOffset=x} = x := !x - wordSize
            fun getOffsetValue {name=_, formals=_, numLocals=_, curOffset=x} = !x
        in
            incrementNumLocals frame';
            case escape of
                true => (incrementOffset frame'; InFrame(getOffsetValue frame'))
              | false => InReg(Temp.newtemp())
        end

    fun printFrame {name=n, formals=f, numLocals=nl, curOffset=co} =
        (
        print ("FRAME with name = " ^ (Symbol.name n) ^ "\n");
        print ("numlocals = " ^ Int.toString(!nl) ^ " curOffset = " ^ Int.toString(!co) ^ "\n")
        )

    fun printAccess fraccess =
        case fraccess of
             InFrame offset => print ("inframe " ^ Int.toString(offset) ^ "\n")
           | _ => print "temp\n"

    fun exp (fraccess, frameaddr) = 
        case fraccess of
            InFrame offset => Tr.MEM(Tr.BINOP(Tr.PLUS, frameaddr, Tr.CONST offset))
          | InReg temp => Tr.TEMP(temp)

    fun exp2loc (Tr.MEM exp') = Tr.MEMLOC exp'
      | exp2loc (Tr.TEMP temp') = Tr.TEMPLOC temp'
      | exp2loc (Tr.ESEQ (stm', exp' as Tr.MEM(_))) = Tr.ESEQLOC(stm', exp2loc exp')
      | exp2loc (Tr.ESEQ (stm', exp' as Tr.TEMP(_))) = Tr.ESEQLOC(stm', exp2loc exp')
      | exp2loc _ = (Err.error 0 "Can't convert exp to loc"; Tr.TEMPLOC(Temp.newtemp()))

    (* TODO account for Tiger vs. C distinctions *)
    fun externalCall (s, args) =
      Tr.CALL(Tr.NAME(Temp.namedlabel s), args)

    fun seq[] = Tr.EXP(Tr.CONST 0)
      | seq[stm] = stm
      | seq(stm::stms) = Tr.SEQ(stm,seq(stms))  
    
    fun getRegisterTemps rList = map (fn (t, r) => t) rList

    fun procEntryExit1(frame' : frame, stm : Tr.stm) = 
        let
          (* move args === *)
          val argTemps = getRegisterTemps argregs
          fun moveArgs([], seqList, offset) = seqList
            | moveArgs(a::access, seqList, offset) =
                if offset < 4
                then Tr.MOVE(exp2loc (exp(a, Tr.TEMP FP)), Tr.TEMP (List.nth(argTemps, offset)))::moveArgs(access, seqList, offset + 1)
                else 
                    let
                      val temp = Temp.newtemp()
                    in
                      case a of 
                           InFrame off => moveArgs(access, seqList, offset + 1)
                             (* do nothing? already in correct place 
                              Tr.MOVE(Tr.TEMPLOC temp, (exp(a, Tr.TEMP FP)))::
                              Tr.MOVE(exp2loc (exp(a, Tr.TEMP FP)), Tr.TEMP temp)::
                              moveArgs(access, seqList, offset + 1) *)
                         | InReg te => 
                             (* load from frame into temp reg *)
                             Tr.MOVE(exp2loc (exp(a, Tr.TEMP FP)), Tr.TEMP te)::moveArgs(access, seqList, offset + 1)
                    end
          val moveArgStms = moveArgs(formals frame', [], 0)
          (* === *)
        in
          seq (moveArgStms @ [stm])
        end

    fun procEntryExit2(frame, body) = 
        body @
        [Assem.OPER {assem="",
                 src=getRegisterTemps (specialregs),
                 dst=[], jump=SOME[]}
        ]
      
    fun procEntryExit3(frame' as {name=name', formals=formals', numLocals=numLocals', curOffset=curOffset'} : frame,
                       body, maxNumArgs, regsToSave) =
        let
            val label' = name frame'
            val labelInsn = Assem.LABEL {assem=Symbol.name label' ^ ":\n", lab=label'}

            (* Move $fp from runtime element into $a0, since $a0 is null when tig_main is called
             This instruction should only be added if this frame is the tig_main frame*)
            val moveTig_mainSL = Assem.OPER {assem="move `d0, `s0\n",
                                             src=[FP], dst=[A0], jump=NONE}


            val saveFpToStack = Assem.OPER {assem="sw `d0, -4(`s0)\n",
                                            src=[SP], dst=[FP], jump=NONE}
            (* copy current fp to sp for new frame *)
            val copySpToFpInsn = Assem.OPER {assem="move `d0, `s0\n",
                                             src=[SP], dst=[FP], jump=NONE}

            (* set new SP offset/allocate frame *)
            val spOffset = if maxNumArgs < ARGREGS
                           then !curOffset' - (ARGREGS * wordSize) 
                           else !curOffset' - (maxNumArgs * wordSize)
            (* sml outputs negatives nums with ~ instead of - breaking qtspim *)
            val moveSpInsn = Assem.OPER {assem="addi `d0, `s0, -" ^ Int.toString(abs(spOffset)) ^ "\n",
                                         src=[FP], dst=[SP], jump=NONE}

            fun intToStringFormat(i) = if i < 0
              then ("-" ^ Int.toString(abs(i)))
              else Int.toString(i)

            fun storeRegs([], moveList, offset) = moveList
              | storeRegs(temp::tempList, moveList, offset) = 
                  Assem.OPER {assem="sw `s0, " ^ (intToStringFormat offset) ^ "(`s1)\n", src=[temp, FP], dst=[], jump=NONE}
                  ::storeRegs(tempList, moveList, offset - 4)
            val tempMoveStms = storeRegs(regsToSave, [], ~8)

            fun loadRegs([], moveList, offset) =  moveList
              | loadRegs(temp::tempList, moveList, offset) = 
                  Assem.OPER {assem="lw `d0, " ^ (intToStringFormat offset) ^ "(`s0)\n", src=[FP], dst=[temp], jump=NONE}
                  ::loadRegs(tempList, moveList, offset - 4)
            val tempMoveBackStms = rev(loadRegs(regsToSave, [], ~8)) (* rev for aesthetics *)

            (* deallocate frame, move sp to fp and reset fp from sl *)
            val moveSpToFp = Assem.OPER {assem="move `d0, `s0\n",
                                         src=[FP], dst=[SP], jump=NONE}
            val getPrevFp = Assem.OPER {assem="lw `d0, -4(`s0)\n",
                                        src=[FP], dst=[FP], jump=NONE}

            (* return instruction *)
            val returnInsn = Assem.OPER {assem="jr `d0\n", src=[], dst=[RA],
                                         jump=NONE}
            val body' = [labelInsn]
                        @ (if name' = Symbol.symbol "tig_main" then [moveTig_mainSL] else [])
                        @ [saveFpToStack]
                        @ [copySpToFpInsn]
                        @ [moveSpInsn]
                        @ tempMoveStms
                        @ body
                        @ tempMoveBackStms
                        @ [moveSpToFp]
                        @ [getPrevFp]
                        @ [returnInsn]
        in
            {prolog = "PROCEDURE " ^ Symbol.name (name frame') ^ "\n",
            body = body',
            epilog = "END " ^ Symbol.name (name frame') ^ "\n"}
        end
end
