`timescale 1ns/1ps
module tb_units;
    reg a,b,cin;
    wire hs,hc,fs,fc;
    integer i,n;
    half_adder h(a,b,hs,hc);
    full_adder f(a,b,cin,fs,fc);
    initial begin
        for(i=0;i<8;i=i+1) begin
            {a,b,cin}=i; #1;
            n=a+b;
            if({hc,hs} !== n[1:0]) $fatal(1,"[FAIL] half adder input=%d",i);
            n=a+b+cin;
            if({fc,fs} !== n[1:0]) $fatal(1,"[FAIL] full adder input=%d",i);
        end
        $display("[PASS] tb_units: 8 full-adder and 8 half-adder checks");
        $finish;
    end
endmodule
