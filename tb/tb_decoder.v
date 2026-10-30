`timescale 1ns/1ps
`include "vector_counts.vh"
module tb_decoder;
    reg [31:0] instruction;
    wire [4:0] rd,rs1,rs2;
    wire [31:0] imm;
    wire [2:0] op;
    wire src,rw,mr,mw,invalid;
    reg [71:0] vectors[0:`DECODER_COUNT-1];
    integer i;
    instruction_decoder d(instruction,rd,rs1,rs2,imm,op,src,rw,mr,mw,invalid);
    initial begin
        $readmemh("vectors/decoder.mem",vectors);
        for(i=0;i<`DECODER_COUNT;i=i+1) begin
            instruction=vectors[i][71:40]; #1;
            if({imm,op,src,rw,mr,mw,invalid} !== vectors[i][39:0] ||
               {rd,rs1,rs2} !== {instruction[11:7],instruction[19:15],instruction[24:20]})
                $fatal(1,"[FAIL] decoder vector=%d instruction=%h actual=%h expected=%h",
                       i,instruction,{imm,op,src,rw,mr,mw,invalid},vectors[i][39:0]);
        end
        $display("[PASS] tb_decoder vectors=%0d",`DECODER_COUNT);
        $finish;
    end
endmodule
