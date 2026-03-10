`timescale 1ns/1ps

module vaes_coproc_top #(
    parameter int AXIS_IN_W  = vaes_common_pkg::AXIS_IN_W,
    parameter int AXIS_OUT_W = vaes_common_pkg::AXIS_OUT_W
    ) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic [AXIS_IN_W-1:0]  s_axis_tdata,
    input  logic                  s_axis_tlast,

    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic [AXIS_OUT_W-1:0] m_axis_tdata,
    output logic                  m_axis_tlast
    );

    import vaes_common_pkg::*;

    typedef struct packed {
        logic        valid;
        logic [31:0] inst;
        logic [4:0]  vl;
    } if_stage_t; // type

    typedef struct packed {
        logic         valid;
        vaes_opcode_e op;
        logic [4:0]   rd;
        logic [4:0]   rs1;
        logic [4:0]   rs2;
        logic [4:0]   vl;
        logic [127:0] src1;
        logic [127:0] src2;
    } id_stage_t;

    typedef struct packed {
        logic         valid;
        vaes_opcode_e op;
        logic [4:0]   rd;
        logic [4:0]   vl;
        logic [127:0] src1;
        logic [127:0] src2;
        logic [1:0]   cycles_left;
    } ex_stage_t;

    typedef struct packed {
        logic         valid;
        logic [4:0]   rd;
        logic [127:0] result;
    } mem_stage_t;

    typedef struct packed {
        logic         valid;
        logic [4:0]   rd;
        logic [127:0] result;
    } wb_stage_t;

    // Slave AXI-Stream interface
    logic [7:0]       s_pkt_type;
    logic [31:0]      s_pkt_word0; // first 32-bit word
    logic [4:0]       s_pkt_reg_idx; // register index
    logic [4:0]       s_pkt_vl; // vector length
    logic [127:0]     s_pkt_payload; // data payload
    logic             unused_s_axis_reserved_bits;

    if_stage_t        if_q, if_n; // _q: registered value; _n: next stage value
    id_stage_t        id_q, id_n;
    ex_stage_t        ex_q, ex_n;
    mem_stage_t       mem_q, mem_n;
    wb_stage_t        wb_q, wb_n;
    logic [31:0]      reg_busy_q, reg_busy_n; // register scoreboard
    logic [4:0]       cur_vl_q, cur_vl_n;
    vaes_ctrl_state_e ctrl_state_q, ctrl_state_n;
    logic             out_valid_q, out_valid_n;
    logic [127:0]     out_data_q, out_data_n;

    // Register File.
    logic             rf_we;
    logic [4:0]       rf_waddr;
    logic [127:0]     rf_wdata;
    logic [4:0]       rf_raddr_a;
    logic [4:0]       rf_raddr_b;
    logic [127:0]     rf_rdata_a;
    logic [127:0]     rf_rdata_b;

    // Ex Stage
    logic [127:0] ex_sbox_result;
    logic [127:0] ex_srow_result;
    logic [127:0] ex_mcol_result;
    logic [127:0] ex_ark_result;

    // IF Stage
    logic         if_inst_valid;
    vaes_opcode_e if_op;
    logic [4:0]   if_rd;
    logic [4:0]   if_rs1;
    logic [4:0]   if_rs2;
    logic         if_hazard;
    logic         pipe_empty;
    logic         accept_inst;
    logic         accept_load;
    logic         accept_cfg;
    logic         accept_store;
    logic         dut_assertions_en_q;

    // Master AXI-Stream interface
    assign m_axis_tvalid = out_valid_q;
    assign m_axis_tdata  = out_data_q;
    assign m_axis_tlast  = out_valid_q;

    assign s_pkt_type    = s_axis_tdata[255:248];
    assign s_pkt_word0   = s_axis_tdata[247:216];
    assign s_pkt_reg_idx = s_axis_tdata[215:211];
    assign s_pkt_vl      = s_axis_tdata[210:206];
    assign s_pkt_payload = s_axis_tdata[127:0];
    assign unused_s_axis_reserved_bits = ^s_axis_tdata[205:128];

    assign pipe_empty = !if_q.valid && !id_q.valid && !ex_q.valid && !mem_q.valid && !wb_q.valid;

    assign if_inst_valid = is_vaes_inst(if_q.inst[6:0], if_q.inst[31:26], if_q.inst[25], if_q.inst[14:12]);
    assign if_op         = decode_vaes_opcode(if_q.inst[31:26]);
    assign if_rd         = decode_vd(if_q.inst[11:7]);
    assign if_rs1        = decode_vs1(if_q.inst[19:15]);
    assign if_rs2        = decode_vs2(if_q.inst[24:20]);
    assign if_hazard     =  reg_busy_q[if_rd]  ||
                            reg_busy_q[if_rs1] ||
                            ((if_op == VAES_OP_ARK) && reg_busy_q[if_rs2]);

    always_comb begin
        rf_raddr_a = 5'd0;
        rf_raddr_b = 5'd0;
        if (if_q.valid) begin
            rf_raddr_a = decode_vs1(if_q.inst[19:15]);
            rf_raddr_b = decode_vs2(if_q.inst[24:20]);
        end
        else if (s_axis_tvalid && (s_pkt_type == PKT_STORE)) begin
            rf_raddr_a = s_pkt_reg_idx;
        end
    end

    vaes_regfile u_regfile (
        .clk     (clk),
        .rst_n   (rst_n),
        .we      (rf_we),
        .waddr   (rf_waddr),
        .wdata   (rf_wdata),
        .raddr_a (rf_raddr_a),
        .rdata_a (rf_rdata_a),
        .raddr_b (rf_raddr_b),
        .rdata_b (rf_rdata_b)
    );

    vaes_sbox_unit u_sbox (
        .src_a (ex_q.src1),
        .vl    (ex_q.vl),
        .dst   (ex_sbox_result)
    );

    vaes_srow_unit u_srow (
        .src_a (ex_q.src1),
        .vl    (ex_q.vl),
        .dst   (ex_srow_result)
    );

    vaes_mcol_unit u_mcol (
        .src_a (ex_q.src1),
        .vl    (ex_q.vl),
        .dst   (ex_mcol_result)
    );

    vaes_ark_unit u_ark (
        .src_a (ex_q.src1),
        .src_b (ex_q.src2),
        .vl    (ex_q.vl),
        .dst   (ex_ark_result)
    );

    always_comb begin
        s_axis_tready = 1'b0;
        if (s_axis_tvalid) begin
            unique case (s_pkt_type)
                PKT_INST : s_axis_tready = !if_q.valid;
                PKT_LOAD : s_axis_tready = pipe_empty && !out_valid_q && !reg_busy_q[s_pkt_reg_idx];
                PKT_CFG  : s_axis_tready = pipe_empty && !out_valid_q;
                PKT_STORE: s_axis_tready = pipe_empty && !out_valid_q && !reg_busy_q[s_pkt_reg_idx];
                default  : s_axis_tready = 1'b1;
            endcase
        end
    end

    assign accept_inst  = s_axis_tvalid && s_axis_tready && (s_pkt_type == PKT_INST);
    assign accept_load  = s_axis_tvalid && s_axis_tready && (s_pkt_type == PKT_LOAD);
    assign accept_cfg   = s_axis_tvalid && s_axis_tready && (s_pkt_type == PKT_CFG);
    assign accept_store = s_axis_tvalid && s_axis_tready && (s_pkt_type == PKT_STORE);

    always_comb begin
        if_n         = if_q;
        id_n         = id_q;
        ex_n         = ex_q;
        mem_n        = mem_q;
        wb_n         = wb_q;
        reg_busy_n   = reg_busy_q;
        cur_vl_n     = cur_vl_q;
        ctrl_state_n = ctrl_state_q;
        out_valid_n  = out_valid_q;
        out_data_n   = out_data_q;

        rf_we        = 1'b0;
        rf_waddr     = '0;
        rf_wdata     = '0;

        if (out_valid_q && m_axis_tready) begin
            out_valid_n = 1'b0;
            out_data_n  = '0;
        end

        if (wb_q.valid) begin
            rf_we              = 1'b1;
            rf_waddr           = wb_q.rd;
            rf_wdata           = wb_q.result;
            reg_busy_n[wb_q.rd] = 1'b0;
            wb_n.valid         = 1'b0;
            wb_n.rd            = '0;
            wb_n.result        = '0;
        end

        if (mem_q.valid && !wb_n.valid) begin
            wb_n.valid   = 1'b1;
            wb_n.rd      = mem_q.rd;
            wb_n.result  = mem_q.result;
            mem_n.valid  = 1'b0;
            mem_n.rd     = '0;
            mem_n.result = '0;
        end

        if (ex_q.valid) begin
            if (ex_q.cycles_left != 0) begin
                ex_n.cycles_left = ex_q.cycles_left - 2'd1;
            end
            if ((ex_q.cycles_left == 2'd1) && !mem_n.valid) begin
                mem_n.valid = 1'b1;
                mem_n.rd    = ex_q.rd;
                unique case (ex_q.op)
                    VAES_OP_SBOX: mem_n.result = ex_sbox_result;
                    VAES_OP_SROW: mem_n.result = ex_srow_result;
                    VAES_OP_MCOL: mem_n.result = ex_mcol_result;
                    VAES_OP_ARK : mem_n.result = ex_ark_result;
                    default     : mem_n.result = ex_q.src1;
                endcase
                ex_n.valid       = 1'b0;
                ex_n.op          = VAES_OP_INV;
                ex_n.rd          = '0;
                ex_n.vl          = '0;
                ex_n.src1        = '0;
                ex_n.src2        = '0;
                ex_n.cycles_left = '0;
            end
        end

        if (id_q.valid && !ex_n.valid) begin
            ex_n.valid = 1'b1;
            ex_n.op    = id_q.op;
            ex_n.rd    = id_q.rd;
            ex_n.vl    = id_q.vl;
            ex_n.src1  = id_q.src1;
            ex_n.src2  = id_q.src2;
            unique case (id_q.op)
                VAES_OP_SBOX,
                VAES_OP_MCOL: ex_n.cycles_left = 2'd2;
                default     : ex_n.cycles_left = 2'd1;
            endcase

            id_n.valid = 1'b0;
            id_n.op    = VAES_OP_INV;
            id_n.rd    = '0;
            id_n.rs1   = '0;
            id_n.rs2   = '0;
            id_n.vl    = '0;
            id_n.src1  = '0;
            id_n.src2  = '0;
        end

        if (if_q.valid && if_inst_valid && !id_n.valid && !if_hazard) begin
            id_n.valid = 1'b1;
            id_n.op    = if_op;
            id_n.rd    = if_rd;
            id_n.rs1   = if_rs1;
            id_n.rs2   = if_rs2;
            id_n.vl    = if_q.vl;
            id_n.src1  = rf_rdata_a;
            id_n.src2  = rf_rdata_b;
            reg_busy_n[if_rd] = 1'b1;

            if_n.valid = 1'b0;
            if_n.inst  = '0;
            if_n.vl    = '0;
        end

        if (accept_load) begin
            rf_we    = 1'b1;
            rf_waddr = s_pkt_reg_idx;
            rf_wdata = s_pkt_payload;
        end

        if (accept_cfg && is_valid_vl(s_pkt_vl)) begin
            cur_vl_n = s_pkt_vl;
        end

        if (accept_store) begin
            out_valid_n = 1'b1;
            out_data_n  = rf_rdata_a;
        end

        if (accept_inst) begin
            if_n.valid = 1'b1;
            if_n.inst  = s_pkt_word0;
            if_n.vl    = cur_vl_q;
            end

        if (out_valid_n) begin
            ctrl_state_n = CTRL_EGRESS;
        end
        else if (ex_n.valid && (ex_n.op == VAES_OP_SBOX) && (ex_n.cycles_left != 0)) begin
            ctrl_state_n = CTRL_EX_SBOX;
        end
        else if (ex_n.valid && (ex_n.op == VAES_OP_MCOL) && (ex_n.cycles_left != 0)) begin
            ctrl_state_n = CTRL_EX_MCOL;
        end
        else begin
            ctrl_state_n = CTRL_IDLE;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_q         <= '0;
            id_q         <= '0;
            ex_q         <= '0;
            mem_q        <= '0;
            wb_q         <= '0;
            reg_busy_q   <= '0;
            cur_vl_q     <= 5'd16;
            ctrl_state_q <= CTRL_IDLE;
            out_valid_q  <= 1'b0;
            out_data_q   <= '0;
        end
        else begin
            if_q         <= if_n;
            id_q         <= id_n;
            ex_q         <= ex_n;
            mem_q        <= mem_n;
            wb_q         <= wb_n;
            reg_busy_q   <= reg_busy_n;
            cur_vl_q     <= cur_vl_n;
            ctrl_state_q <= ctrl_state_n;
            out_valid_q  <= out_valid_n;
            out_data_q   <= out_data_n;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dut_assertions_en_q <= 1'b0;
        end
        else begin
            dut_assertions_en_q <= 1'b1;
        end
    end

    property p_input_last_on_accept;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        s_axis_tvalid && s_axis_tready |-> s_axis_tlast;
    endproperty
    assert property (p_input_last_on_accept);

    property p_output_hold_when_stalled;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        m_axis_tvalid && !m_axis_tready |=> m_axis_tvalid && $stable(m_axis_tdata) && $stable(m_axis_tlast);
    endproperty
    assert property (p_output_hold_when_stalled);

    property p_ctrl_sbox_matches_ex;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        ctrl_state_q == CTRL_EX_SBOX |-> ex_q.valid && (ex_q.op == VAES_OP_SBOX);
    endproperty
    assert property (p_ctrl_sbox_matches_ex);

    property p_ctrl_mcol_matches_ex;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        ctrl_state_q == CTRL_EX_MCOL |-> ex_q.valid && (ex_q.op == VAES_OP_MCOL);
    endproperty
    assert property (p_ctrl_mcol_matches_ex);

    property p_ctrl_egress_matches_out;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        ctrl_state_q == CTRL_EGRESS |-> out_valid_q;
    endproperty
    assert property (p_ctrl_egress_matches_out);

    property p_wb_commits_busy_reg;
        @(posedge clk) disable iff (!dut_assertions_en_q)
        wb_q.valid |-> reg_busy_q[wb_q.rd];
    endproperty
    assert property (p_wb_commits_busy_reg);

    endmodule
