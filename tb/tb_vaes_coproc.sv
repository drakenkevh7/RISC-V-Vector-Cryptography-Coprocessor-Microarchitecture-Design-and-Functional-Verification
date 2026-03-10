`timescale 1ns/1ps

module tb_vaes_coproc;

    import vaes_common_pkg::*;
    import tb_vaes_pkg::*;

    `include "vaes_ref_model.svh"

    logic                  clk;
    logic                  rst_n;
    logic                  s_axis_tvalid;
    logic                  s_axis_tready;
    logic [AXIS_IN_W-1:0]  s_axis_tdata;
    logic                  s_axis_tlast;
    logic                  m_axis_tvalid;
    logic                  m_axis_tready;
    logic [AXIS_OUT_W-1:0] m_axis_tdata;
    logic                  m_axis_tlast;

    vaes_ref_model refm;

    logic [127:0] expected_q[0:2047];
    int unsigned  exp_head;
    int unsigned  exp_tail;
    int unsigned  total_passes;
    int unsigned  total_tests;
    int unsigned  seed_base;
    int           n_aes_random;
    int           n_vl_random;
    int           gap_cycles;
    logic         tb_assertions_en_q;
    vaes_rand_sequencer rand_seqr;
    vaes_rand_seq_item  rand_item;

`ifndef VERILATOR
    int unsigned cov_vl;
    int unsigned cov_payload_mode;
    covergroup cg_vl_payload;
        option.per_instance = 1;
        cp_vl: coverpoint cov_vl {
            bins vl4  = {4};
            bins vl8  = {8};
            bins vl12 = {12};
            bins vl16 = {16};
        }
        cp_payload_mode: coverpoint cov_payload_mode {
            bins zero   = {0};
            bins random = {1};
            bins dense  = {2};
        }
        cross cp_vl, cp_payload_mode;
    endgroup
`endif

    vaes_coproc_top dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata (m_axis_tdata),
        .m_axis_tlast (m_axis_tlast)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [127:0] rand_block128();
        rand_block128 = {$urandom, $urandom, $urandom, $urandom};
    endfunction

    task automatic queue_expected(input logic [127:0] expected);
        expected_q[exp_tail] = expected;
        exp_tail             = exp_tail + 1;
    endtask

    task automatic clear_expected_queue();
        exp_head = 0;
        exp_tail = 0;
    endtask

    task automatic reset_env();
        integer i;
        begin
            rst_n         = 1'b0;
            s_axis_tvalid = 1'b0;
            s_axis_tdata  = '0;
            s_axis_tlast  = 1'b0;
            m_axis_tready = 1'b0;
            clear_expected_queue();
            refm.reset();
            for (i = 0; i < 5; i++) begin
                @(posedge clk);
            end
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic drive_pkt(input axis_pkt_t pkt);
        logic [AXIS_IN_W-1:0] raw_pkt;
        raw_pkt = pkt;
        @(negedge clk);
        s_axis_tdata  = raw_pkt;
        s_axis_tvalid = 1'b1;
        s_axis_tlast  = 1'b1;
        while (1) begin
            @(posedge clk);
            if (s_axis_tready) begin
                break;
            end
        end
        @(negedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tdata  = '0;
        s_axis_tlast  = 1'b0;

        gap_cycles = $urandom_range(0, 2);
        repeat (gap_cycles) @(posedge clk);
    endtask

    task automatic wait_for_expected_drain(input string tag);
        int timeout_cycles;
        timeout_cycles = 0;
        while ((exp_head != exp_tail) && (timeout_cycles < 20000)) begin
            @(posedge clk);
            timeout_cycles++;
        end
        if (exp_head != exp_tail) begin
            $fatal(1, "Timeout while waiting for DUT outputs to drain in test '%0s'", tag);
        end
        repeat (8) @(posedge clk);
    endtask

    task automatic write_aes_sequence_file(
        input string        filename,
        input logic [127:0] plaintext,
        input logic [127:0] key
    );
        integer       fd;
        logic [127:0] round_keys[0:10];
        int           r;

        refm.expand_round_keys(key, round_keys);

        fd = $fopen(filename, "w");
        if (fd == 0) begin
            $fatal(1, "Cannot open '%0s' for write", filename);
        end

        $fdisplay(fd, "# AES-128 program emitted by the self-checking testbench");
        $fdisplay(fd, "CFG VL 16");
        $fdisplay(fd, "LOAD V0 %032h", plaintext);
        for (r = 0; r < 11; r++) begin
            $fdisplay(fd, "LOAD V%0d %032h", r + 1, round_keys[r]);
        end

        $fdisplay(fd, "INST vaes.ark.v V0 V0 V1");
        for (r = 1; r < 10; r++) begin
            $fdisplay(fd, "INST vaes.sbox.v V0 V0");
            $fdisplay(fd, "INST vaes.srow.v V0 V0");
            $fdisplay(fd, "INST vaes.mcol.v V0 V0");
            $fdisplay(fd, "INST vaes.ark.v V0 V0 V%0d", r + 1);
        end
        $fdisplay(fd, "INST vaes.sbox.v V0 V0");
        $fdisplay(fd, "INST vaes.srow.v V0 V0");
        $fdisplay(fd, "INST vaes.ark.v V0 V0 V11");
        $fdisplay(fd, "STORE V0");

        $fclose(fd);
    endtask

    task automatic write_partial_directed_file(input string filename);
        integer fd;
        fd = $fopen(filename, "w");
        if (fd == 0) begin
            $fatal(1, "Cannot open '%0s' for write", filename);
        end

        $fdisplay(fd, "# Directed non-full-length coverage");
        $fdisplay(fd, "CFG VL 4");
        $fdisplay(fd, "LOAD V0 00112233445566778899aabbccddeeff");
        $fdisplay(fd, "LOAD V1 0f0e0d0c0b0a09080706050403020100");
        $fdisplay(fd, "INST vaes.sbox.v V2 V0");
        $fdisplay(fd, "INST vaes.ark.v V3 V2 V1");
        $fdisplay(fd, "STORE V3");

        $fdisplay(fd, "CFG VL 8");
        $fdisplay(fd, "LOAD V4 89abcdef012345670123456789abcdef");
        $fdisplay(fd, "INST vaes.srow.v V5 V4");
        $fdisplay(fd, "STORE V5");

        $fdisplay(fd, "CFG VL 12");
        $fdisplay(fd, "LOAD V6 fedcba98765432100123456789abcdef");
        $fdisplay(fd, "INST vaes.mcol.v V7 V6");
        $fdisplay(fd, "STORE V7");

        $fdisplay(fd, "CFG VL 16");
        $fdisplay(fd, "LOAD V8 0f1571c947d9e8590cb7add6af7f6798");
        $fdisplay(fd, "LOAD V9 ffeeddccbbaa99887766554433221100");
        $fdisplay(fd, "INST vaes.sbox.v V10 V8");
        $fdisplay(fd, "INST vaes.srow.v V11 V10");
        $fdisplay(fd, "INST vaes.mcol.v V12 V11");
        $fdisplay(fd, "INST vaes.ark.v V13 V12 V9");
        $fdisplay(fd, "STORE V13");

        $fclose(fd);
    endtask

    task automatic write_random_instruction_file(
        input string             filename,
        input vaes_rand_seq_item item
    );
        integer fd;
        int     i;
        int     op_sel;
        int     rd;
        int     rs1;
        int     rs2;
        int     store_idx;
        int     byte_idx;
        logic [127:0] data_block;

        fd = $fopen(filename, "w");
        if (fd == 0) begin
            $fatal(1, "Cannot open '%0s' for write", filename);
        end

        $fdisplay(fd, "CFG VL %0d", item.vl);

`ifndef VERILATOR
        cov_vl           = item.vl;
        cov_payload_mode = item.payload_mode;
        cg_vl_payload.sample();
`endif

        for (i = 0; i < item.n_loads; i++) begin
            unique case (item.payload_mode)
                0: data_block = '0;
                1: data_block = rand_block128();
                default: begin
                    data_block = '0;
                    for (byte_idx = 0; byte_idx < 16; byte_idx++) begin
                        data_block[(byte_idx*8) +: 8] = byte'($urandom_range(0, 255));
                    end
                end
            endcase
            $fdisplay(fd, "LOAD V%0d %032h", i, data_block);
        end

        for (i = item.n_loads; i < 8; i++) begin
            data_block = rand_block128();
            $fdisplay(fd, "LOAD V%0d %032h", i, data_block);
        end

        for (i = 0; i < item.n_ops; i++) begin
            op_sel = $urandom_range(0, 3);
            rd     = $urandom_range(0, 7);
            rs1    = $urandom_range(0, 7);
            rs2    = $urandom_range(0, 7);

            case (op_sel)
                0: $fdisplay(fd, "INST vaes.sbox.v V%0d V%0d", rd, rs1);
                1: $fdisplay(fd, "INST vaes.srow.v V%0d V%0d", rd, rs1);
                2: $fdisplay(fd, "INST vaes.mcol.v V%0d V%0d", rd, rs1);
                default: $fdisplay(fd, "INST vaes.ark.v V%0d V%0d V%0d", rd, rs1, rs2);
            endcase

            if ($urandom_range(0, item.store_rate) == 0) begin
                store_idx = $urandom_range(0, 7);
                $fdisplay(fd, "STORE V%0d", store_idx);
            end
        end

        store_idx = $urandom_range(0, 7);
        $fdisplay(fd, "STORE V%0d", store_idx);

        $fclose(fd);
    endtask

    task automatic run_sequence_file(input string filename, input string tag);
        integer       fd;
        string        line;
        string        mnemonic;
        int           n;
        int           reg_a;
        int           reg_b;
        int           reg_c;
        int           cfg_vl;
        logic [127:0] data_block;
        logic [31:0]  inst_word;
        axis_pkt_t    pkt;

        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $fatal(1, "Cannot open '%0s' for read", filename);
        end

        $display("RUNNING TEST: %0s (%0s)", tag, filename);

        while ($fgets(line, fd) != 0) begin
            if (line_is_blank_or_comment(line)) begin
                continue;
            end

            mnemonic  = "";
            reg_a     = 0;
            reg_b     = 0;
            reg_c     = 0;
            cfg_vl    = 0;
            data_block = '0;

            if ($sscanf(line, "CFG VL %d", cfg_vl) == 1) begin
                pkt = make_cfg_pkt(cfg_vl[4:0]);
                refm.set_vl(cfg_vl);
                drive_pkt(pkt);
            end
            else if ($sscanf(line, "LOAD V%d %h", reg_a, data_block) == 2) begin
                pkt = make_load_pkt(reg_a[4:0], data_block);
                refm.load_reg(reg_a, data_block);
                drive_pkt(pkt);
            end
            else if ($sscanf(line, "STORE V%d", reg_a) == 1) begin
                pkt = make_store_pkt(reg_a[4:0]);
                queue_expected(refm.read_reg(reg_a));
                drive_pkt(pkt);
            end
            else begin
                n = $sscanf(line, "INST %s V%d V%d V%d", mnemonic, reg_a, reg_b, reg_c);
                if (n == 4) begin
                    if ((reg_a < 0) || (reg_a > 31) || (reg_b < 0) || (reg_b > 31) ||
                        (reg_c < 0) || (reg_c > 31)) begin
                            $fatal(1, "Vector register index out of range in line: %0s", line);
                    end
                    inst_word = encode_vaes_inst(mnemonic_to_op(mnemonic), reg_a[4:0], reg_b[4:0], reg_c[4:0]);
                    refm.exec_inst(inst_word);
                    pkt = make_inst_pkt(inst_word);
                    drive_pkt(pkt);
                end
                else begin
                    n = $sscanf(line, "INST %s V%d V%d", mnemonic, reg_a, reg_b);
                    if (n == 3) begin
                        if ((reg_a < 0) || (reg_a > 31) || (reg_b < 0) || (reg_b > 31)) begin
                            $fatal(1, "Vector register index out of range in line: %0s", line);
                        end
                        inst_word = encode_vaes_inst(mnemonic_to_op(mnemonic), reg_a[4:0], reg_b[4:0], 5'd0);
                        refm.exec_inst(inst_word);
                        pkt = make_inst_pkt(inst_word);
                        drive_pkt(pkt);
                    end
                    else begin
                        $fatal(1, "Unsupported sequence line: %0s", line);
                    end
                end
            end
        end

        $fclose(fd);
        wait_for_expected_drain(tag);
        total_tests = total_tests + 1;
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tready <= 1'b0;
        end
        else begin
            m_axis_tready <= ($urandom_range(0, 3) != 0);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb_assertions_en_q <= 1'b0;
        end
        else begin
            tb_assertions_en_q <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            if (exp_head == exp_tail) begin
                $fatal(1, "Received an unexpected output packet: %032h", m_axis_tdata);
            end
            if (m_axis_tdata !== expected_q[exp_head]) begin
                $display("EXPECTED: %032h", expected_q[exp_head]);
                $display("ACTUAL  : %032h", m_axis_tdata);
                $fatal(1, "Scoreboard mismatch on output index %0d", exp_head);
            end
            exp_head     <= exp_head + 1;
            total_passes <= total_passes + 1;
        end
    end

    property p_tb_input_hold;
        @(posedge clk) disable iff (!tb_assertions_en_q)
        s_axis_tvalid && !s_axis_tready |=> s_axis_tvalid && $stable(s_axis_tdata) && $stable(s_axis_tlast);
    endproperty
    assert property (p_tb_input_hold);

    property p_tb_output_last;
        @(posedge clk) disable iff (!tb_assertions_en_q)
        m_axis_tvalid |-> m_axis_tlast;
    endproperty
    assert property (p_tb_output_last);

    initial begin
        logic [127:0] plaintext;
        logic [127:0] key;
        integer       aes_idx;
        integer       vl_idx;

        seed_base    = 32'h1bad_f00d;
        n_aes_random = 8;
        n_vl_random  = 12;

        if (!$value$plusargs("SEED=%d", seed_base)) begin
        end
        if (!$value$plusargs("N_AES_RANDOM=%d", n_aes_random)) begin
        end
        if (!$value$plusargs("N_VL_RANDOM=%d", n_vl_random)) begin
        end

        void'($urandom(seed_base));

        refm         = new();
        rand_seqr    = new();
`ifndef VERILATOR
        cg_vl_payload = new();
`endif
        total_passes = 0;
        total_tests  = 0;

        reset_env();

        write_aes_sequence_file("tb/seq_nist_aes128.txt",
        128'h00112233445566778899aabbccddeeff,
        128'h000102030405060708090a0b0c0d0e0f);
        run_sequence_file("tb/seq_nist_aes128.txt", "NIST AES-128");

        reset_env();

        write_partial_directed_file("tb/seq_directed_partial_vl.txt");
        run_sequence_file("tb/seq_directed_partial_vl.txt", "Directed variable-VL ISA checks");

        for (aes_idx = 0; aes_idx < n_aes_random; aes_idx++) begin
            plaintext = rand_block128();
            key       = rand_block128();
            reset_env();
            write_aes_sequence_file($sformatf("tb/generated_aes_%0d.txt", aes_idx),
                                    plaintext, key);
            run_sequence_file($sformatf("tb/generated_aes_%0d.txt", aes_idx),
                                $sformatf("Random AES case %0d", aes_idx));
        end

        for (vl_idx = 0; vl_idx < n_vl_random; vl_idx++) begin
            reset_env();
            rand_seqr.randomize_next(rand_item);
            $display("[SEQUENCER] item[%0d]: %0s", vl_idx, rand_item.sprint());
            write_random_instruction_file($sformatf("tb/generated_vl_%0d.txt", vl_idx), rand_item);
            run_sequence_file($sformatf("tb/generated_vl_%0d.txt", vl_idx),
                                $sformatf("Random variable-VL case %0d", vl_idx));
        end

        rand_seqr.report_coverage();
        if (!rand_seqr.has_full_cross_coverage()) begin
            $fatal(1, "Sequence-level cross coverage (VL x payload mode) is incomplete");
        end

`ifndef VERILATOR
        if (cg_vl_payload.get_coverage() < 100.0) begin
            $fatal(1, "Covergroup cross coverage is incomplete: %0.2f%%", cg_vl_payload.get_coverage());
        end
        $display("[COVERAGE] cg_vl_payload coverage: %0.2f%%", cg_vl_payload.get_coverage());
`else
        $display("[COVERAGE] VERILATOR build: using sequencer cross-hit counters as coverage proxy.");
`endif

        $display("PASS: %0d tests completed, %0d output packets matched the reference model.", total_tests, total_passes);
        $finish;
    end

    endmodule
