`timescale 1ns/1ps
`default_nettype none
`include "alu_defs.vh"
module addsub_behavioral #(parameter WIDTH=8)(
    input wire [WIDTH-1:0] a,b, input wire sub,
    output reg [WIDTH-1:0] result, output reg carry,overflow
);
    reg [WIDTH:0] extended;
    always @(*) begin
        extended={1'b0,a}+{1'b0,b};
        if(sub) begin
            extended={1'b0,a}-{1'b0,b};
            result=extended[WIDTH-1:0];
            carry=(a>=b); // architectural convention: one means no borrow
            overflow=(a[WIDTH-1]!=b[WIDTH-1]) && (result[WIDTH-1]!=a[WIDTH-1]);
        end else begin
            result=extended[WIDTH-1:0];
            carry=extended[WIDTH];
            overflow=(a[WIDTH-1]==b[WIDTH-1]) && (result[WIDTH-1]!=a[WIDTH-1]);
        end
    end
endmodule

module alu_behavioral #(parameter WIDTH=8, parameter SHAMT=$clog2(WIDTH))(
    input wire [WIDTH-1:0] a,b, input wire [2:0] op,
    output reg [WIDTH-1:0] result, output reg carry,zero,negative,overflow
);
    wire [WIDTH-1:0] arithmetic_result;
    wire ac,av;
    wire sub=(op==`ALU_SUB);
    addsub_behavioral #(WIDTH) arithmetic_unit(a,b,sub,arithmetic_result,ac,av);
    always @(*) begin
        result={WIDTH{1'b0}}; carry=1'b0; overflow=1'b0;
        case(op)
            `ALU_ADD,`ALU_SUB: begin result=arithmetic_result; carry=ac; overflow=av; end
            `ALU_AND: result=a & b;
            `ALU_OR:  result=a | b;
            `ALU_XOR: result=a ^ b;
            `ALU_SLL: result=a << b[SHAMT-1:0];
            `ALU_SRL: result=a >> b[SHAMT-1:0];
            `ALU_SLT: result={{(WIDTH-1){1'b0}},($signed(a)<$signed(b))};
            default: result={WIDTH{1'b0}};
        endcase
        zero=(result=={WIDTH{1'b0}});
        negative=result[WIDTH-1];
    end
endmodule

module alu #(parameter WIDTH=8, parameter STRUCTURAL=1)(
    input wire [WIDTH-1:0] a,b, input wire [2:0] op,
    output wire [WIDTH-1:0] result, output wire carry,zero,negative,overflow
);
    generate if(STRUCTURAL) begin: gates
        alu_structural #(WIDTH) core(a,b,op,result,carry,zero,negative,overflow);
    end else begin: rtl
        alu_behavioral #(WIDTH) core(a,b,op,result,carry,zero,negative,overflow);
    end endgenerate
endmodule
`default_nettype wire
