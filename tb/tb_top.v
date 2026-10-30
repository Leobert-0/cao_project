`timescale 1ns/1ps
`include "vector_counts.vh"
module tb_top;
    reg clk=0,reset=1,enable=0;
    reg [31:0] instruction=0;
    wire [7:0] a,b,result,wb,md,ab,bb,rb,wbb,mdb;
    wire [3:0] flags,fb;
    wire [4:0] rd,rs1,rs2,rdb,r1b,r2b;
    wire [31:0] imm,immb;
    wire [2:0] op,opb;
    wire src,rw,mr,mw,invalid,srcb,rwb,mrb,mwb,ib;
    reg [108:0] vectors[0:`PROGRAM_COUNT-1];
    reg [7:0] expected_registers[0:31],expected_memory[0:255];
    integer i,trace;
    demo_datapath #(1) structural(clk,reset,enable,instruction,a,b,result,wb,md,flags,
                                 rd,rs1,rs2,imm,op,src,rw,mr,mw,invalid);
    demo_datapath #(0) behavioral(clk,reset,enable,instruction,ab,bb,rb,wbb,mdb,fb,
                                 rdb,r1b,r2b,immb,opb,srcb,rwb,mrb,mwb,ib);
    initial begin
        $dumpfile("results/demo.vcd"); $dumpvars(0,tb_top);
        $readmemh("vectors/program.mem",vectors);
        $readmemh("vectors/final_registers.mem",expected_registers);
        $readmemh("vectors/final_memory.mem",expected_memory);
        trace=$fopen("results/execution_trace.csv","w");
        if(!trace) $fatal(1,"Cannot open trace");
        $fdisplay(trace,"step,time_ns,instruction,enable,rd,rs1,rs2,immediate,op,alu_src,reg_write,mem_read,mem_write,invalid,a,b,result,writeback,CZNV");
        #5; clk=1; #5; clk=0; reset=0;
        for(i=0;i<`PROGRAM_COUNT;i=i+1) begin
            {enable,instruction}=vectors[i][108:76]; #5;
            if({wb,flags,op,src,rw,mr,mw,invalid,imm,a,b,result} !== vectors[i][75:0]) begin
                $error("Datapath differs from file-driven golden trace");
                $fatal(1,"[FAIL] demo step=%0d actual=%h expected=%h",i,
                       {wb,flags,op,src,rw,mr,mw,invalid,imm,a,b,result},vectors[i][75:0]);
            end
            if({ab,bb,rb,wbb,mdb,fb,rdb,r1b,r2b,immb,opb,srcb,rwb,mrb,mwb,ib} !==
               {a,b,result,wb,md,flags,rd,rs1,rs2,imm,op,src,rw,mr,mw,invalid})
                $fatal(1,"[FAIL] demo style equivalence");
            $fdisplay(trace,"%0d,%0d,%08h,%b,%0d,%0d,%0d,%08h,%0d,%b,%b,%b,%b,%b,%02h,%02h,%02h,%02h,%04b",
                      i,$time,instruction,enable,rd,rs1,rs2,imm,op,src,rw,mr,mw,invalid,a,b,result,wb,flags);
            $display("[PASS] demo step=%0d instr=%08h a=%02h b=%02h result=%02h CZNV=%b",i,instruction,a,b,result,flags);
            clk=1; #5; clk=0;
        end
        for(i=0;i<32;i=i+1)
            if(structural.registers[i] !== expected_registers[i] || behavioral.registers[i] !== expected_registers[i])
                $fatal(1,"[FAIL] final register x%0d",i);
        for(i=0;i<256;i=i+1)
            if(structural.memory[i] !== expected_memory[i] || behavioral.memory[i] !== expected_memory[i])
                $fatal(1,"[FAIL] final memory byte %0d",i);
        reset=1; clk=1; #5;
        for(i=0;i<32;i=i+1)
            if(structural.registers[i] !== 0 || behavioral.registers[i] !== 0) $fatal(1,"reset register");
        for(i=0;i<256;i=i+1)
            if(structural.memory[i] !== 0 || behavioral.memory[i] !== 0) $fatal(1,"reset memory");
        $fclose(trace);
        $display("[PASS] tb_top instructions=%0d; final registers/memory, stall, x0, reset checked",`PROGRAM_COUNT);
        $finish;
    end
endmodule
