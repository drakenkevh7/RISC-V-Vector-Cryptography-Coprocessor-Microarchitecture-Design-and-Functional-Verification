`timescale 1ns/1ps

package tb_vaes_pkg;

    import vaes_common_pkg::*;

    function automatic vaes_opcode_e mnemonic_to_op(input string mnemonic);
        if (mnemonic == "vaes.sbox.v") begin
            mnemonic_to_op = VAES_OP_SBOX;
        end
        else if (mnemonic == "vaes.srow.v") begin
            mnemonic_to_op = VAES_OP_SROW;
        end
        else if (mnemonic == "vaes.mcol.v") begin
            mnemonic_to_op = VAES_OP_MCOL;
        end
        else if (mnemonic == "vaes.ark.v") begin
            mnemonic_to_op = VAES_OP_ARK;
        end
        else begin
            mnemonic_to_op = VAES_OP_INV;
        end
    endfunction

    function automatic bit line_is_blank_or_comment(input string line);
        int  i;
        byte ch;
        line_is_blank_or_comment = 1'b1;
        for (i = 0; i < line.len(); i++) begin
            ch = line.getc(i);
            if ((ch == 8'h20) || (ch == 8'h09) || (ch == 8'h0a) || (ch == 8'h0d)) begin
            end
            else begin
                if (ch == 8'h23) begin
                    line_is_blank_or_comment = 1'b1;
                end
                else begin
                    line_is_blank_or_comment = 1'b0;
                end
                break;
            end
        end
    endfunction

endpackage
