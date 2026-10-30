`timescale 1ns/1ps
// Independent integer-range reference: does not reuse DUT carry/overflow equations.
module tb_alu;
    parameter WIDTH=8;
    localparam LIMIT=(1<<WIDTH), MASK=LIMIT-1, HALF=LIMIT/2;
    reg [WIDTH-1:0] a,b;
    reg [2:0] op;
    wire [WIDTH-1:0] sr,br,sa,ba;
    wire sc,sz,sn,sv,bc,bz,bn,bv,sac,sav,bac,bav;
    reg sub;
    integer ai,bi,oi,total,signed_a,signed_b,math,shift_amount;
    integer expected,ec,ev,ez,en,seed,k,extent;
    reg [WIDTH+3:0] golden;
    alu_structural #(WIDTH) s(a,b,op,sr,sc,sz,sn,sv);
    alu_behavioral #(WIDTH) r(a,b,op,br,bc,bz,bn,bv);
    addsub_structural #(WIDTH) as_(a,b,sub,sa,sac,sav);
    addsub_behavioral #(WIDTH) ab(a,b,sub,ba,bac,bav);
    task check;
        begin
            signed_a=(a>=HALF) ? a-LIMIT : a;
            signed_b=(b>=HALF) ? b-LIMIT : b;
            shift_amount=b % WIDTH;
            ec=0; ev=0; math=0;
            case(op)
                0: begin
                    expected=(a+b)&MASK; ec=(a+b)>=LIMIT;
                    math=signed_a+signed_b;
                end
                1: begin
                    expected=(a-b)&MASK; ec=(a>=b);
                    math=signed_a-signed_b;
                end
                2: expected=a & b;
                3: expected=a | b;
                4: expected=a ^ b;
                5: expected=(a*(1<<shift_amount))&MASK;
                6: expected=a/(1<<shift_amount);
                7: expected=(signed_a<signed_b);
            endcase
            if(op<2) ev=(math < -HALF || math >= HALF);
            ez=(expected==0); en=(expected>=HALF);
            golden={expected[WIDTH-1:0],ec[0],ez[0],en[0],ev[0]};
            #1;
            if({sr,sc,sz,sn,sv} !== golden || {br,bc,bz,bn,bv} !== golden) begin
                $error("ALU result or flags differ from independent reference");
                $fatal(1,"[FAIL] W=%0d op=%d a=%h b=%h structural=%h behavioral=%h golden=%h",
                       WIDTH,op,a,b,{sr,sc,sz,sn,sv},{br,bc,bz,bn,bv},golden);
            end
            if(op<2 && ({sa,sac,sav} !== {expected[WIDTH-1:0],ec[0],ev[0]} ||
                         {ba,bac,bav} !== {expected[WIDTH-1:0],ec[0],ev[0]}))
                $fatal(1,"[FAIL] standalone adder/subtractor");
            total=total+1;
        end
    endtask
    initial begin
        total=0; seed=32'h2c0a2026;
        if(WIDTH<=8) begin
            for(oi=0;oi<8;oi=oi+1) begin
                op=oi; sub=(oi==1);
                for(ai=0;ai<LIMIT;ai=ai+1)
                    for(bi=0;bi<LIMIT;bi=bi+1) begin a=ai; b=bi; check; end
            end
        end else begin
            // Cartesian boundary grid plus deterministic random tests for every op.
            for(oi=0;oi<8;oi=oi+1) begin
                op=oi; sub=(oi==1);
                for(ai=0;ai<8;ai=ai+1) for(bi=0;bi<8;bi=bi+1) begin
                    case(ai)
                        0:a=0; 1:a=1; 2:a=MASK; 3:a=HALF; 4:a=HALF-1;
                        5:a=HALF+1; 6:a=WIDTH-1; 7:a=WIDTH;
                    endcase
                    case(bi)
                        0:b=0; 1:b=1; 2:b=MASK; 3:b=HALF; 4:b=HALF-1;
                        5:b=HALF+1; 6:b=WIDTH-1; 7:b=WIDTH;
                    endcase
                    check;
                end
                for(k=0;k<2048;k=k+1) begin a=$random(seed); b=$random(seed); check; end
            end
        end
        $display("[PASS] tb_alu WIDTH=%0d vectors=%0d simulated_ns=%0d",WIDTH,total,$time);
        $finish;
    end
endmodule
