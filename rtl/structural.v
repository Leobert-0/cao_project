`timescale 1ns/1ps
`default_nettype none
// Synthesizable structural datapath: no behavioral arithmetic or mux operators.
module half_adder(input wire a, b, output wire sum, carry);
    xor (sum, a, b);
    and (carry, a, b);
endmodule

module full_adder(input wire a, b, cin, output wire sum, cout);
    wire s, c0, c1;
    half_adder h0(a, b, s, c0);
    half_adder h1(s, cin, sum, c1);
    or (cout, c0, c1);
endmodule

module mux2_gate(input wire a, b, sel, output wire y);
    wire ns, x, z;
    not (ns, sel);
    and (x, a, ns);
    and (z, b, sel);
    or (y, x, z);
endmodule

module mux_word #(parameter WIDTH=8)(
    input wire [WIDTH-1:0] a, b, input wire sel,
    output wire [WIDTH-1:0] y
);
    genvar i;
    generate for (i=0; i<WIDTH; i=i+1) begin: bits_mux
        mux2_gate m(a[i], b[i], sel, y[i]);
    end endgenerate
endmodule

module ripple_carry_adder #(parameter WIDTH=8)(
    input wire [WIDTH-1:0] a, b, input wire cin,
    output wire [WIDTH-1:0] sum, output wire cout, carry_into_msb
);
    wire [WIDTH:0] c;
    assign c[0]=cin;
    assign cout=c[WIDTH];
    assign carry_into_msb=c[WIDTH-1];
    genvar i;
    generate for (i=0; i<WIDTH; i=i+1) begin: stages
        full_adder fa(a[i], b[i], c[i], sum[i], c[i+1]);
    end endgenerate
endmodule

module addsub_structural #(parameter WIDTH=8)(
    input wire [WIDTH-1:0] a, b, input wire sub,
    output wire [WIDTH-1:0] result, output wire carry, overflow
);
    wire [WIDTH-1:0] bx;
    wire cm;
    genvar i;
    generate for (i=0; i<WIDTH; i=i+1) begin: invert_b
        xor (bx[i], b[i], sub);
    end endgenerate
    ripple_carry_adder #(WIDTH) rca(a, bx, sub, result, carry, cm);
    xor (overflow, cm, carry);
endmodule

// WIDTH must be a power of two >= 2. Stage k shifts by constant 2**k.
module shift_structural #(parameter WIDTH=8, parameter SHAMT=$clog2(WIDTH))(
    input wire [WIDTH-1:0] a, input wire [SHAMT-1:0] amount,
    output wire [WIDTH-1:0] left_result, right_result
);
    wire [WIDTH-1:0] ls[0:SHAMT], rs[0:SHAMT];
    assign ls[0]=a;
    assign rs[0]=a;
    assign left_result=ls[SHAMT];
    assign right_result=rs[SHAMT];
    genvar k, i;
    generate for (k=0; k<SHAMT; k=k+1) begin: level
        for (i=0; i<WIDTH; i=i+1) begin: bit_stage
            if (i >= (1<<k)) begin: left_data
                mux2_gate m(ls[k][i], ls[k][i-(1<<k)], amount[k], ls[k+1][i]);
            end else begin: left_zero
                mux2_gate m(ls[k][i], 1'b0, amount[k], ls[k+1][i]);
            end
            if (i+(1<<k) < WIDTH) begin: right_data
                mux2_gate m(rs[k][i], rs[k][i+(1<<k)], amount[k], rs[k+1][i]);
            end else begin: right_zero
                mux2_gate m(rs[k][i], 1'b0, amount[k], rs[k+1][i]);
            end
        end
    end endgenerate
endmodule

module alu_structural #(parameter WIDTH=8, parameter SHAMT=$clog2(WIDTH))(
    input wire [WIDTH-1:0] a, b, input wire [2:0] op,
    output wire [WIDTH-1:0] result, output wire carry, zero, negative, overflow
);
    wire n0,n1,n2, sub, slt, ov, cy, arithmetic;
    wire [7:0] select;
    wire [WIDTH-1:0] ar, la, lo, lx, ll, lr, lt;
    wire [WIDTH-1:0] m0,m1,m2,m3,m4,m5;
    not(n0,op[0]); not(n1,op[1]); not(n2,op[2]);
    and(select[0],n2,n1,n0); and(select[1],n2,n1,op[0]);
    and(select[2],n2,op[1],n0); and(select[3],n2,op[1],op[0]);
    and(select[4],op[2],n1,n0); and(select[5],op[2],n1,op[0]);
    and(select[6],op[2],op[1],n0); and(select[7],op[2],op[1],op[0]);
    or(sub,select[1],select[7]);
    or(arithmetic,select[0],select[1]);
    addsub_structural #(WIDTH) arithmetic_unit(a,b,sub,ar,cy,ov);
    xor(slt,ar[WIDTH-1],ov);
    assign lt={{(WIDTH-1){1'b0}},slt};
    shift_structural #(WIDTH) shifter(a,b[SHAMT-1:0],ll,lr);
    genvar i;
    generate for(i=0;i<WIDTH;i=i+1) begin: logic_bits
        and(la[i],a[i],b[i]); or(lo[i],a[i],b[i]); xor(lx[i],a[i],b[i]);
    end endgenerate
    // Binary mux tree: 0/1 arithmetic, 2 AND, 3 OR, 4 XOR, 5 SLL, 6 SRL, 7 SLT.
    mux_word #(WIDTH) a0(ar,ar,op[0],m0);
    mux_word #(WIDTH) a1(la,lo,op[0],m1);
    mux_word #(WIDTH) a2(lx,ll,op[0],m2);
    mux_word #(WIDTH) a3(lr,lt,op[0],m3);
    mux_word #(WIDTH) b0(m0,m1,op[1],m4);
    mux_word #(WIDTH) b1(m2,m3,op[1],m5);
    mux_word #(WIDTH) c0(m4,m5,op[2],result);
    and(carry,cy,arithmetic); and(overflow,ov,arithmetic);
    assign zero=~(|result); // reduction NOR gate
    assign negative=result[WIDTH-1];
endmodule
`default_nettype wire
