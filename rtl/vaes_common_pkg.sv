`timescale 1ns/1ps

package vaes_common_pkg;

    localparam logic [6:0] VAES_CUSTOM_OPCODE = 7'b0001011;

    typedef enum logic [2:0] {
        VAES_OP_INV  = 3'd0,
        VAES_OP_SBOX = 3'd1,
        VAES_OP_SROW = 3'd2,
        VAES_OP_MCOL = 3'd3,
        VAES_OP_ARK  = 3'd4
    } vaes_opcode_e;

    typedef enum logic [1:0] {
        CTRL_IDLE    = 2'd0,
        CTRL_EX_SBOX = 2'd1,
        CTRL_EX_MCOL = 2'd2,
        CTRL_EGRESS  = 2'd3
    } vaes_ctrl_state_e;

    localparam logic [7:0] PKT_LOAD  = 8'h01;
    localparam logic [7:0] PKT_INST  = 8'h02;
    localparam logic [7:0] PKT_CFG   = 8'h03;
    localparam logic [7:0] PKT_STORE = 8'h04;

    typedef struct packed {
        logic [7:0]   pkt_type;
        logic [31:0]  word0;
        logic [4:0]   reg_idx;
        logic [4:0]   vl;
        logic [77:0]  reserved;
        logic [127:0] payload;
    } axis_pkt_t;

    localparam int AXIS_IN_W  = $bits(axis_pkt_t);
    localparam int AXIS_OUT_W = 128;

    function automatic logic is_valid_vl(input logic [4:0] vl);
        is_valid_vl = ((vl == 5'd4) || (vl == 5'd8) || (vl == 5'd12) || (vl == 5'd16));
    endfunction

    function automatic logic is_vaes_inst(
        input logic [6:0] opcode,
        input logic [5:0] funct6,
        input logic       vm,
        input logic [2:0] funct3
    );
        is_vaes_inst =  (opcode == VAES_CUSTOM_OPCODE) &&
                        (vm == 1'b1)           &&
                        (funct3 == 3'b000)     &&
                        ((funct6 == 6'b000000) ||
                        (funct6 == 6'b000001)  ||
                        (funct6 == 6'b000010)  ||
                        (funct6 == 6'b000011));
    endfunction

    function automatic vaes_opcode_e decode_vaes_opcode(input logic [5:0] funct6);
        case (funct6)
            6'b000000: decode_vaes_opcode = VAES_OP_SBOX;
            6'b000001: decode_vaes_opcode = VAES_OP_SROW;
            6'b000010: decode_vaes_opcode = VAES_OP_MCOL;
            6'b000011: decode_vaes_opcode = VAES_OP_ARK;
            default:   decode_vaes_opcode = VAES_OP_INV;
        endcase
    endfunction

    function automatic logic [4:0] decode_vd(input logic [4:0] vd);
        decode_vd = vd;
    endfunction

    function automatic logic [4:0] decode_vs1(input logic [4:0] vs1);
        decode_vs1 = vs1;
    endfunction

    function automatic logic [4:0] decode_vs2(input logic [4:0] vs2);
        decode_vs2 = vs2;
    endfunction

    function automatic logic [31:0] encode_vaes_inst(
        input vaes_opcode_e op,
        input logic [4:0]   vd,
        input logic [4:0]   vs1,
        input logic [4:0]   vs2
    );
        logic [5:0] funct6;
        case (op)
            VAES_OP_SBOX: funct6 = 6'b000000;
            VAES_OP_SROW: funct6 = 6'b000001;
            VAES_OP_MCOL: funct6 = 6'b000010;
            VAES_OP_ARK : funct6 = 6'b000011;
            default     : funct6 = 6'b111111;
        endcase
        encode_vaes_inst = {funct6, 1'b1, vs2, vs1, 3'b000, vd, VAES_CUSTOM_OPCODE};
    endfunction

    function automatic axis_pkt_t make_inst_pkt(input logic [31:0] inst_word);
        axis_pkt_t pkt;
        pkt = '0;
        pkt.pkt_type = PKT_INST;
        pkt.word0    = inst_word;
        make_inst_pkt = pkt;
    endfunction

    function automatic axis_pkt_t make_load_pkt(
        input logic [4:0]   reg_idx,
        input logic [127:0] payload
    );
        axis_pkt_t pkt;
        pkt = '0;
        pkt.pkt_type = PKT_LOAD;
        pkt.reg_idx  = reg_idx;
        pkt.payload  = payload;
        make_load_pkt = pkt;
    endfunction

    function automatic axis_pkt_t make_cfg_pkt(input logic [4:0] vl);
        axis_pkt_t pkt;
        pkt = '0;
        pkt.pkt_type = PKT_CFG;
        pkt.vl       = vl;
        make_cfg_pkt = pkt;
    endfunction

    function automatic axis_pkt_t make_store_pkt(input logic [4:0] reg_idx);
        axis_pkt_t pkt;
        pkt = '0;
        pkt.pkt_type = PKT_STORE;
        pkt.reg_idx  = reg_idx;
        make_store_pkt = pkt;
    endfunction

    endpackage
