`timescale 1ns/1ps

module vaes_srow_unit (
    input  logic [127:0] src_a,
    input  logic [4:0]   vl,
    output logic [127:0] dst
    );

    import vaes_aes_pkg::*;

    always_comb begin
        dst = aes_shiftrows(src_a, vl);
    end
    
endmodule
