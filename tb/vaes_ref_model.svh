class vaes_ref_model;

	logic [127:0] vreg[0:31];
	int unsigned  vl;

	function new();
		reset();
	endfunction

	function void reset();
		int i;
		for (i = 0; i < 32; i++) begin
			vreg[i] = '0;
		end
		vl = 16;
	endfunction

	function void set_vl(input int unsigned new_vl);
		if ((new_vl == 4) || (new_vl == 8) || (new_vl == 12) || (new_vl == 16)) begin
			vl = new_vl;
		end
	endfunction

	function void load_reg(input int unsigned idx, input logic [127:0] data);
		if (idx < 32) begin
			vreg[idx] = data;
		end
	endfunction

	function logic [127:0] read_reg(input int unsigned idx);
		if (idx < 32) begin
			read_reg = vreg[idx];
		end
		else begin
			read_reg = '0;
		end
	endfunction

	function automatic logic [7:0] sbox_byte(input logic [7:0] value);
		case (value)
			8'h00: sbox_byte = 8'h63;
			8'h01: sbox_byte = 8'h7c;
			8'h02: sbox_byte = 8'h77;
			8'h03: sbox_byte = 8'h7b;
			8'h04: sbox_byte = 8'hf2;
			8'h05: sbox_byte = 8'h6b;
			8'h06: sbox_byte = 8'h6f;
			8'h07: sbox_byte = 8'hc5;
			8'h08: sbox_byte = 8'h30;
			8'h09: sbox_byte = 8'h01;
			8'h0a: sbox_byte = 8'h67;
			8'h0b: sbox_byte = 8'h2b;
			8'h0c: sbox_byte = 8'hfe;
			8'h0d: sbox_byte = 8'hd7;
			8'h0e: sbox_byte = 8'hab;
			8'h0f: sbox_byte = 8'h76;
			8'h10: sbox_byte = 8'hca;
			8'h11: sbox_byte = 8'h82;
			8'h12: sbox_byte = 8'hc9;
			8'h13: sbox_byte = 8'h7d;
			8'h14: sbox_byte = 8'hfa;
			8'h15: sbox_byte = 8'h59;
			8'h16: sbox_byte = 8'h47;
			8'h17: sbox_byte = 8'hf0;
			8'h18: sbox_byte = 8'had;
			8'h19: sbox_byte = 8'hd4;
			8'h1a: sbox_byte = 8'ha2;
			8'h1b: sbox_byte = 8'haf;
			8'h1c: sbox_byte = 8'h9c;
			8'h1d: sbox_byte = 8'ha4;
			8'h1e: sbox_byte = 8'h72;
			8'h1f: sbox_byte = 8'hc0;
			8'h20: sbox_byte = 8'hb7;
			8'h21: sbox_byte = 8'hfd;
			8'h22: sbox_byte = 8'h93;
			8'h23: sbox_byte = 8'h26;
			8'h24: sbox_byte = 8'h36;
			8'h25: sbox_byte = 8'h3f;
			8'h26: sbox_byte = 8'hf7;
			8'h27: sbox_byte = 8'hcc;
			8'h28: sbox_byte = 8'h34;
			8'h29: sbox_byte = 8'ha5;
			8'h2a: sbox_byte = 8'he5;
			8'h2b: sbox_byte = 8'hf1;
			8'h2c: sbox_byte = 8'h71;
			8'h2d: sbox_byte = 8'hd8;
			8'h2e: sbox_byte = 8'h31;
			8'h2f: sbox_byte = 8'h15;
			8'h30: sbox_byte = 8'h04;
			8'h31: sbox_byte = 8'hc7;
			8'h32: sbox_byte = 8'h23;
			8'h33: sbox_byte = 8'hc3;
			8'h34: sbox_byte = 8'h18;
			8'h35: sbox_byte = 8'h96;
			8'h36: sbox_byte = 8'h05;
			8'h37: sbox_byte = 8'h9a;
			8'h38: sbox_byte = 8'h07;
			8'h39: sbox_byte = 8'h12;
			8'h3a: sbox_byte = 8'h80;
			8'h3b: sbox_byte = 8'he2;
			8'h3c: sbox_byte = 8'heb;
			8'h3d: sbox_byte = 8'h27;
			8'h3e: sbox_byte = 8'hb2;
			8'h3f: sbox_byte = 8'h75;
			8'h40: sbox_byte = 8'h09;
			8'h41: sbox_byte = 8'h83;
			8'h42: sbox_byte = 8'h2c;
			8'h43: sbox_byte = 8'h1a;
			8'h44: sbox_byte = 8'h1b;
			8'h45: sbox_byte = 8'h6e;
			8'h46: sbox_byte = 8'h5a;
			8'h47: sbox_byte = 8'ha0;
			8'h48: sbox_byte = 8'h52;
			8'h49: sbox_byte = 8'h3b;
			8'h4a: sbox_byte = 8'hd6;
			8'h4b: sbox_byte = 8'hb3;
			8'h4c: sbox_byte = 8'h29;
			8'h4d: sbox_byte = 8'he3;
			8'h4e: sbox_byte = 8'h2f;
			8'h4f: sbox_byte = 8'h84;
			8'h50: sbox_byte = 8'h53;
			8'h51: sbox_byte = 8'hd1;
			8'h52: sbox_byte = 8'h00;
			8'h53: sbox_byte = 8'hed;
			8'h54: sbox_byte = 8'h20;
			8'h55: sbox_byte = 8'hfc;
			8'h56: sbox_byte = 8'hb1;
			8'h57: sbox_byte = 8'h5b;
			8'h58: sbox_byte = 8'h6a;
			8'h59: sbox_byte = 8'hcb;
			8'h5a: sbox_byte = 8'hbe;
			8'h5b: sbox_byte = 8'h39;
			8'h5c: sbox_byte = 8'h4a;
			8'h5d: sbox_byte = 8'h4c;
			8'h5e: sbox_byte = 8'h58;
			8'h5f: sbox_byte = 8'hcf;
			8'h60: sbox_byte = 8'hd0;
			8'h61: sbox_byte = 8'hef;
			8'h62: sbox_byte = 8'haa;
			8'h63: sbox_byte = 8'hfb;
			8'h64: sbox_byte = 8'h43;
			8'h65: sbox_byte = 8'h4d;
			8'h66: sbox_byte = 8'h33;
			8'h67: sbox_byte = 8'h85;
			8'h68: sbox_byte = 8'h45;
			8'h69: sbox_byte = 8'hf9;
			8'h6a: sbox_byte = 8'h02;
			8'h6b: sbox_byte = 8'h7f;
			8'h6c: sbox_byte = 8'h50;
			8'h6d: sbox_byte = 8'h3c;
			8'h6e: sbox_byte = 8'h9f;
			8'h6f: sbox_byte = 8'ha8;
			8'h70: sbox_byte = 8'h51;
			8'h71: sbox_byte = 8'ha3;
			8'h72: sbox_byte = 8'h40;
			8'h73: sbox_byte = 8'h8f;
			8'h74: sbox_byte = 8'h92;
			8'h75: sbox_byte = 8'h9d;
			8'h76: sbox_byte = 8'h38;
			8'h77: sbox_byte = 8'hf5;
			8'h78: sbox_byte = 8'hbc;
			8'h79: sbox_byte = 8'hb6;
			8'h7a: sbox_byte = 8'hda;
			8'h7b: sbox_byte = 8'h21;
			8'h7c: sbox_byte = 8'h10;
			8'h7d: sbox_byte = 8'hff;
			8'h7e: sbox_byte = 8'hf3;
			8'h7f: sbox_byte = 8'hd2;
			8'h80: sbox_byte = 8'hcd;
			8'h81: sbox_byte = 8'h0c;
			8'h82: sbox_byte = 8'h13;
			8'h83: sbox_byte = 8'hec;
			8'h84: sbox_byte = 8'h5f;
			8'h85: sbox_byte = 8'h97;
			8'h86: sbox_byte = 8'h44;
			8'h87: sbox_byte = 8'h17;
			8'h88: sbox_byte = 8'hc4;
			8'h89: sbox_byte = 8'ha7;
			8'h8a: sbox_byte = 8'h7e;
			8'h8b: sbox_byte = 8'h3d;
			8'h8c: sbox_byte = 8'h64;
			8'h8d: sbox_byte = 8'h5d;
			8'h8e: sbox_byte = 8'h19;
			8'h8f: sbox_byte = 8'h73;
			8'h90: sbox_byte = 8'h60;
			8'h91: sbox_byte = 8'h81;
			8'h92: sbox_byte = 8'h4f;
			8'h93: sbox_byte = 8'hdc;
			8'h94: sbox_byte = 8'h22;
			8'h95: sbox_byte = 8'h2a;
			8'h96: sbox_byte = 8'h90;
			8'h97: sbox_byte = 8'h88;
			8'h98: sbox_byte = 8'h46;
			8'h99: sbox_byte = 8'hee;
			8'h9a: sbox_byte = 8'hb8;
			8'h9b: sbox_byte = 8'h14;
			8'h9c: sbox_byte = 8'hde;
			8'h9d: sbox_byte = 8'h5e;
			8'h9e: sbox_byte = 8'h0b;
			8'h9f: sbox_byte = 8'hdb;
			8'ha0: sbox_byte = 8'he0;
			8'ha1: sbox_byte = 8'h32;
			8'ha2: sbox_byte = 8'h3a;
			8'ha3: sbox_byte = 8'h0a;
			8'ha4: sbox_byte = 8'h49;
			8'ha5: sbox_byte = 8'h06;
			8'ha6: sbox_byte = 8'h24;
			8'ha7: sbox_byte = 8'h5c;
			8'ha8: sbox_byte = 8'hc2;
			8'ha9: sbox_byte = 8'hd3;
			8'haa: sbox_byte = 8'hac;
			8'hab: sbox_byte = 8'h62;
			8'hac: sbox_byte = 8'h91;
			8'had: sbox_byte = 8'h95;
			8'hae: sbox_byte = 8'he4;
			8'haf: sbox_byte = 8'h79;
			8'hb0: sbox_byte = 8'he7;
			8'hb1: sbox_byte = 8'hc8;
			8'hb2: sbox_byte = 8'h37;
			8'hb3: sbox_byte = 8'h6d;
			8'hb4: sbox_byte = 8'h8d;
			8'hb5: sbox_byte = 8'hd5;
			8'hb6: sbox_byte = 8'h4e;
			8'hb7: sbox_byte = 8'ha9;
			8'hb8: sbox_byte = 8'h6c;
			8'hb9: sbox_byte = 8'h56;
			8'hba: sbox_byte = 8'hf4;
			8'hbb: sbox_byte = 8'hea;
			8'hbc: sbox_byte = 8'h65;
			8'hbd: sbox_byte = 8'h7a;
			8'hbe: sbox_byte = 8'hae;
			8'hbf: sbox_byte = 8'h08;
			8'hc0: sbox_byte = 8'hba;
			8'hc1: sbox_byte = 8'h78;
			8'hc2: sbox_byte = 8'h25;
			8'hc3: sbox_byte = 8'h2e;
			8'hc4: sbox_byte = 8'h1c;
			8'hc5: sbox_byte = 8'ha6;
			8'hc6: sbox_byte = 8'hb4;
			8'hc7: sbox_byte = 8'hc6;
			8'hc8: sbox_byte = 8'he8;
			8'hc9: sbox_byte = 8'hdd;
			8'hca: sbox_byte = 8'h74;
			8'hcb: sbox_byte = 8'h1f;
			8'hcc: sbox_byte = 8'h4b;
			8'hcd: sbox_byte = 8'hbd;
			8'hce: sbox_byte = 8'h8b;
			8'hcf: sbox_byte = 8'h8a;
			8'hd0: sbox_byte = 8'h70;
			8'hd1: sbox_byte = 8'h3e;
			8'hd2: sbox_byte = 8'hb5;
			8'hd3: sbox_byte = 8'h66;
			8'hd4: sbox_byte = 8'h48;
			8'hd5: sbox_byte = 8'h03;
			8'hd6: sbox_byte = 8'hf6;
			8'hd7: sbox_byte = 8'h0e;
			8'hd8: sbox_byte = 8'h61;
			8'hd9: sbox_byte = 8'h35;
			8'hda: sbox_byte = 8'h57;
			8'hdb: sbox_byte = 8'hb9;
			8'hdc: sbox_byte = 8'h86;
			8'hdd: sbox_byte = 8'hc1;
			8'hde: sbox_byte = 8'h1d;
			8'hdf: sbox_byte = 8'h9e;
			8'he0: sbox_byte = 8'he1;
			8'he1: sbox_byte = 8'hf8;
			8'he2: sbox_byte = 8'h98;
			8'he3: sbox_byte = 8'h11;
			8'he4: sbox_byte = 8'h69;
			8'he5: sbox_byte = 8'hd9;
			8'he6: sbox_byte = 8'h8e;
			8'he7: sbox_byte = 8'h94;
			8'he8: sbox_byte = 8'h9b;
			8'he9: sbox_byte = 8'h1e;
			8'hea: sbox_byte = 8'h87;
			8'heb: sbox_byte = 8'he9;
			8'hec: sbox_byte = 8'hce;
			8'hed: sbox_byte = 8'h55;
			8'hee: sbox_byte = 8'h28;
			8'hef: sbox_byte = 8'hdf;
			8'hf0: sbox_byte = 8'h8c;
			8'hf1: sbox_byte = 8'ha1;
			8'hf2: sbox_byte = 8'h89;
			8'hf3: sbox_byte = 8'h0d;
			8'hf4: sbox_byte = 8'hbf;
			8'hf5: sbox_byte = 8'he6;
			8'hf6: sbox_byte = 8'h42;
			8'hf7: sbox_byte = 8'h68;
			8'hf8: sbox_byte = 8'h41;
			8'hf9: sbox_byte = 8'h99;
			8'hfa: sbox_byte = 8'h2d;
			8'hfb: sbox_byte = 8'h0f;
			8'hfc: sbox_byte = 8'hb0;
			8'hfd: sbox_byte = 8'h54;
			8'hfe: sbox_byte = 8'hbb;
			8'hff: sbox_byte = 8'h16;
			default: sbox_byte = 8'h00;
		endcase
	endfunction

	function automatic logic [7:0] xtime(input logic [7:0] value);
		xtime = {value[6:0], 1'b0} ^ (8'h1b & {8{value[7]}});
	endfunction

	function automatic logic [7:0] mul2(input logic [7:0] value);
		mul2 = xtime(value);
	endfunction

	function automatic logic [7:0] mul3(input logic [7:0] value);
		mul3 = xtime(value) ^ value;
	endfunction

	function automatic logic [127:0] subbytes(
		input logic [127:0] src,
		input int unsigned  active_vl
	);
		logic [127:0] dst;
		logic [7:0]   byte_v;
		int           i;
		dst = src;
		for (i = 0; i < 16; i++) begin
			byte_v = src[127 - (i*8) -: 8];
			if (i < active_vl) begin
				dst[127 - (i*8) -: 8] = sbox_byte(byte_v);
			end
			else begin
				dst[127 - (i*8) -: 8] = byte_v;
			end
		end
		subbytes = dst;
	endfunction

	function automatic logic [127:0] shiftrows(
		input logic [127:0] src,
		input int unsigned  active_vl
	);
		logic [127:0] dst;
		logic [7:0]   in_b [0:15];
		logic [7:0]   out_b[0:15];
		logic [7:0]   row_b[0:3];
		int           i;
		int           r;
		int           c;
		int           active_cols;
		int           shift;
		active_cols = active_vl / 4;
		for (i = 0; i < 16; i++) begin
			in_b[i]  = src[127 - (i*8) -: 8];
			out_b[i] = in_b[i];
		end
		if (active_cols > 0) begin
			for (r = 0; r < 4; r++) begin
				for (c = 0; c < active_cols; c++) begin
					row_b[c] = in_b[(4*c) + r];
				end
				shift = r % active_cols;
				for (c = 0; c < active_cols; c++) begin
					out_b[(4*c) + r] = row_b[(c + shift) % active_cols];
				end
			end
		end
		dst = '0;
		for (i = 0; i < 16; i++) begin
			dst[127 - (i*8) -: 8] = out_b[i];
		end
		shiftrows = dst;
	endfunction

	function automatic logic [127:0] mixcolumns(
		input logic [127:0] src,
		input int unsigned  active_vl
	);
		logic [127:0] dst;
		logic [7:0]   in_b [0:15];
		logic [7:0]   out_b[0:15];
		logic [7:0]   a0;
		logic [7:0]   a1;
		logic [7:0]   a2;
		logic [7:0]   a3;
		int           i;
		int           c;
		int           active_cols;
		active_cols = active_vl / 4;
		for (i = 0; i < 16; i++) begin
			in_b[i]  = src[127 - (i*8) -: 8];
			out_b[i] = in_b[i];
		end
		for (c = 0; c < active_cols; c++) begin
			a0 = in_b[(4*c) + 0];
			a1 = in_b[(4*c) + 1];
			a2 = in_b[(4*c) + 2];
			a3 = in_b[(4*c) + 3];
			out_b[(4*c) + 0] = mul2(a0) ^ mul3(a1) ^ a2 ^ a3;
			out_b[(4*c) + 1] = a0 ^ mul2(a1) ^ mul3(a2) ^ a3;
			out_b[(4*c) + 2] = a0 ^ a1 ^ mul2(a2) ^ mul3(a3);
			out_b[(4*c) + 3] = mul3(a0) ^ a1 ^ a2 ^ mul2(a3);
		end
		dst = '0;
		for (i = 0; i < 16; i++) begin
			dst[127 - (i*8) -: 8] = out_b[i];
		end
		mixcolumns = dst;
	endfunction

	function automatic logic [127:0] addroundkey(
		input logic [127:0] src,
		input logic [127:0] key,
		input int unsigned  active_vl
	);
		logic [127:0] dst;
		logic [7:0]   src_b;
		logic [7:0]   key_b;
		int           i;
		dst = src;
		for (i = 0; i < 16; i++) begin
			src_b = src[127 - (i*8) -: 8];
			key_b = key[127 - (i*8) -: 8];
			if (i < active_vl) begin
				dst[127 - (i*8) -: 8] = src_b ^ key_b;
			end
			else begin
				dst[127 - (i*8) -: 8] = src_b;
			end
		end
		addroundkey = dst;
	endfunction

	function automatic logic [31:0] rotword(input logic [31:0] value);
		rotword = {value[23:0], value[31:24]};
	endfunction

	function automatic logic [31:0] subword(input logic [31:0] value);
		subword = {
		sbox_byte(value[31:24]),
		sbox_byte(value[23:16]),
		sbox_byte(value[15:8]),
		sbox_byte(value[7:0])
		};
	endfunction

	task automatic expand_round_keys(
		input  logic [127:0] key,
		output logic [127:0] round_keys[0:10]
	);
		logic [31:0] w[0:43];
		logic [31:0] temp;
		logic [31:0] rcon[0:9];
		int          i;

		rcon[0] = 32'h0100_0000;
		rcon[1] = 32'h0200_0000;
		rcon[2] = 32'h0400_0000;
		rcon[3] = 32'h0800_0000;
		rcon[4] = 32'h1000_0000;
		rcon[5] = 32'h2000_0000;
		rcon[6] = 32'h4000_0000;
		rcon[7] = 32'h8000_0000;
		rcon[8] = 32'h1b00_0000;
		rcon[9] = 32'h3600_0000;

		w[0] = key[127:96];
		w[1] = key[95:64];
		w[2] = key[63:32];
		w[3] = key[31:0];

		for (i = 4; i < 44; i++) begin
			temp = w[i-1];
			if ((i % 4) == 0) begin
				temp = subword(rotword(temp)) ^ rcon[(i/4)-1];
			end
			w[i] = w[i-4] ^ temp;
		end

		for (i = 0; i < 11; i++) begin
			round_keys[i] = {w[(4*i)+0], w[(4*i)+1], w[(4*i)+2], w[(4*i)+3]};
		end
	endtask

	task automatic aes128_encrypt(
		input  logic [127:0] plaintext,
		input  logic [127:0] key,
		output logic [127:0] ciphertext
	);
		logic [127:0] round_keys[0:10];
		logic [127:0] state;
		int           round_idx;

		expand_round_keys(key, round_keys);

		state = addroundkey(plaintext, round_keys[0], 16);
		for (round_idx = 1; round_idx < 10; round_idx++) begin
			state = subbytes(state, 16);
			state = shiftrows(state, 16);
			state = mixcolumns(state, 16);
			state = addroundkey(state, round_keys[round_idx], 16);
		end
		state = subbytes(state, 16);
		state = shiftrows(state, 16);
		state = addroundkey(state, round_keys[10], 16);

		ciphertext = state;
	endtask

	function void exec_inst(input logic [31:0] inst_word);
		vaes_opcode_e op;
		logic [4:0]   rd;
		logic [4:0]   rs1;
		logic [4:0]   rs2;
		if (!is_vaes_inst(inst_word[6:0], inst_word[31:26], inst_word[25], inst_word[14:12])) begin
			return;
		end

		op  = decode_vaes_opcode(inst_word[31:26]);
		rd  = decode_vd(inst_word[11:7]);
		rs1 = decode_vs1(inst_word[19:15]);
		rs2 = decode_vs2(inst_word[24:20]);

		case (op)
			VAES_OP_SBOX: vreg[rd] = subbytes(vreg[rs1], vl);
			VAES_OP_SROW: vreg[rd] = shiftrows(vreg[rs1], vl);
			VAES_OP_MCOL: vreg[rd] = mixcolumns(vreg[rs1], vl);
			VAES_OP_ARK : vreg[rd] = addroundkey(vreg[rs1], vreg[rs2], vl);
			default     : vreg[rd] = vreg[rs1];
		endcase
	endfunction

endclass
