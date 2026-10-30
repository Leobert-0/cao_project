`timescale 1ns/1ps
// Used by both Yosys/Icarus and Vivado/XSim netlist flows.
module tb_post;
    reg [7:0] a,b;
    reg [2:0] op;
    wire [7:0] result;
    wire carry,zero,negative,overflow;
    reg [30:0] vectors[0:23];
    integer i;
    alu_netlist dut(.a(a),.b(b),.op(op),.result(result),.carry(carry),
                    .zero(zero),.negative(negative),.overflow(overflow));
    initial begin
        $readmemh("vectors/alu_directed.mem",vectors);
        for(i=0;i<24;i=i+1) begin
            {op,a,b}=vectors[i][30:12]; #20;
            if({result,carry,zero,negative,overflow} !== vectors[i][11:0])
                $fatal(1,"[FAIL] netlist vector=%d actual=%h expected=%h",i,
                       {result,carry,zero,negative,overflow},vectors[i][11:0]);
        end
        $display("[PASS] tb_post vectors=24"); $finish;
    end
endmodule
