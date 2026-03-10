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

    /* verilator lint_off DECLFILENAME */
    class vaes_rand_seq_item;
        int unsigned vl           = 16;
        int unsigned n_loads      = 8;
        int unsigned n_ops        = 20;
        int unsigned store_rate   = 4;
        int unsigned payload_mode = 1;

        function string sprint();
            return $sformatf("vl=%0d n_loads=%0d n_ops=%0d store_rate=%0d payload_mode=%0d",
                              vl, n_loads, n_ops, store_rate, payload_mode);
        endfunction
    endclass
    /* verilator lint_on DECLFILENAME */

    /* verilator lint_off DECLFILENAME */
    class vaes_rand_sequencer;
        localparam int NUM_VL = 4;
        localparam int NUM_PAYLOAD = 3;
        int unsigned coverage_hits[NUM_VL][NUM_PAYLOAD];
        int unsigned generated_items;

        function new();
            reset_coverage();
        endfunction

        function void reset_coverage();
            int i;
            int j;
            for (i = 0; i < NUM_VL; i++) begin
                for (j = 0; j < NUM_PAYLOAD; j++) begin
                    coverage_hits[i][j] = 0;
                end
            end
            generated_items = 0;
        endfunction

        function automatic logic [1:0] map_vl_to_bin(input int unsigned vl);
            case (vl)
                4: map_vl_to_bin = 0;
                8: map_vl_to_bin = 1;
                12: map_vl_to_bin = 2;
                default: map_vl_to_bin = 3;
            endcase
        endfunction

        function automatic bit has_full_cross_coverage();
            int i;
            int j;
            for (i = 0; i < NUM_VL; i++) begin
                for (j = 0; j < NUM_PAYLOAD; j++) begin
                    if (coverage_hits[i][j] == 0) begin
                        return 1'b0;
                    end
                end
            end
            return 1'b1;
        endfunction

        function void sample_item(input vaes_rand_seq_item item);
            logic [1:0] vl_bin;
            vl_bin = map_vl_to_bin(item.vl);
            coverage_hits[vl_bin][item.payload_mode]++;
            generated_items++;
        endfunction

        function void randomize_next(ref vaes_rand_seq_item item);
            int i;
            int j;
            item = new();

            item.vl           = 16;
            item.n_loads      = $urandom_range(4, 8);
            item.n_ops        = $urandom_range(12, 48);
            item.store_rate   = $urandom_range(2, 6);
            item.payload_mode = $urandom_range(0, 2);

            for (i = 0; i < NUM_VL; i++) begin
                for (j = 0; j < NUM_PAYLOAD; j++) begin
                    if (coverage_hits[i][j] == 0) begin
                        case (i)
                            0: item.vl = 4;
                            1: item.vl = 8;
                            2: item.vl = 12;
                            default: item.vl = 16;
                        endcase
                        item.payload_mode = j;
                        sample_item(item);
                        return;
                    end
                end
            end

            case ($urandom_range(0, 3))
                0: item.vl = 4;
                1: item.vl = 8;
                2: item.vl = 12;
                default: item.vl = 16;
            endcase
            sample_item(item);
        endfunction

        function void report_coverage();
            int i;
            int j;
            $display("[SEQUENCER] Generated items: %0d", generated_items);
            for (i = 0; i < NUM_VL; i++) begin
                for (j = 0; j < NUM_PAYLOAD; j++) begin
                    $display("[SEQUENCER] cross(vl_bin=%0d, payload_mode=%0d) hits=%0d",
                             i, j, coverage_hits[i][j]);
                end
            end
        endfunction
    endclass
    /* verilator lint_on DECLFILENAME */

endpackage
