`timescale 1ns/1ps
`default_nettype none
`include "alu_defs.vh"
// Limited RV32 encoding decoder; execution data is intentionally only 8 bits.
module instruction_decoder(
    input wire [31:0] instruction,
    output wire [4:0] rd,rs1,rs2,
    output reg [31:0] immediate,
    output reg [2:0] alu_op,
    output reg alu_src,reg_write,mem_read,mem_write,invalid
);
    wire [6:0] opcode=instruction[6:0], funct7=instruction[31:25];
    wire [2:0] funct3=instruction[14:12];
    assign rd=instruction[11:7]; assign rs1=instruction[19:15]; assign rs2=instruction[24:20];
    always @(*) begin
        immediate={{20{instruction[31]}},instruction[31:20]};
        alu_op=`ALU_ADD; alu_src=0; reg_write=0; mem_read=0; mem_write=0; invalid=0;
        case(opcode)
            7'b0110011: begin
                reg_write=1;
                case({funct7,funct3})
                    {7'h00,3'h0}: alu_op=`ALU_ADD;
                    {7'h20,3'h0}: alu_op=`ALU_SUB;
                    {7'h00,3'h7}: alu_op=`ALU_AND;
                    {7'h00,3'h6}: alu_op=`ALU_OR;
                    {7'h00,3'h4}: alu_op=`ALU_XOR;
                    {7'h00,3'h1}: alu_op=`ALU_SLL;
                    {7'h00,3'h5}: alu_op=`ALU_SRL;
                    {7'h00,3'h2}: alu_op=`ALU_SLT;
                    default: invalid=1;
                endcase
            end
            7'b0010011: begin
                reg_write=1; alu_src=1;
                case(funct3)
                    3'h0: alu_op=`ALU_ADD;
                    3'h7: alu_op=`ALU_AND;
                    3'h6: alu_op=`ALU_OR;
                    3'h4: alu_op=`ALU_XOR;
                    3'h2: alu_op=`ALU_SLT;
                    3'h1: begin alu_op=`ALU_SLL; if(funct7!=0) invalid=1; end
                    3'h5: begin alu_op=`ALU_SRL; if(funct7!=0) invalid=1; end
                    default: invalid=1;
                endcase
            end
            7'b0000011: begin
                alu_src=1; reg_write=1; mem_read=1;
                if(funct3!=0) invalid=1; // LB only
            end
            7'b0100011: begin
                immediate={{20{instruction[31]}},instruction[31:25],instruction[11:7]};
                alu_src=1; mem_write=1;
                if(funct3!=0) invalid=1; // SB only
            end
            default: invalid=1;
        endcase
        if(invalid) begin reg_write=0; mem_read=0; mem_write=0; end
    end
endmodule

module demo_datapath #(parameter STRUCTURAL=1)(
    input wire clk,reset,enable, input wire [31:0] instruction,
    output wire [7:0] operand_a,operand_b,result,writeback,memory_data,
    output wire [3:0] flags,
    output wire [4:0] rd,rs1,rs2,
    output wire [31:0] immediate,
    output wire [2:0] alu_op,
    output wire alu_src,reg_write,mem_read,mem_write,invalid
);
    reg [7:0] registers[0:31];
    reg [7:0] memory[0:255];
    wire [7:0] register_b=registers[rs2];
    assign operand_a=registers[rs1];
    instruction_decoder decoder(instruction,rd,rs1,rs2,immediate,alu_op,
                                alu_src,reg_write,mem_read,mem_write,invalid);
    mux_word #(8) operand_mux(register_b,immediate[7:0],alu_src,operand_b);
    alu #(8,STRUCTURAL) arithmetic_unit(operand_a,operand_b,alu_op,result,
                                     flags[3],flags[2],flags[1],flags[0]);
    assign memory_data=memory[result];
    mux_word #(8) writeback_mux(result,memory_data,mem_read,writeback);
    integer i;
    always @(posedge clk) begin
        if(reset) begin
            for(i=0;i<32;i=i+1) registers[i]<=0;
            for(i=0;i<256;i=i+1) memory[i]<=0;
        end else if(enable && !invalid) begin
            if(reg_write && rd!=0) registers[rd]<=writeback;
            if(mem_write) memory[result]<=register_b;
        end
    end
endmodule
`default_nettype wire
