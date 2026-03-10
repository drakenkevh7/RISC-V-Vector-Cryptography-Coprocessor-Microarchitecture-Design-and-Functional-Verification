`timescale 1ns/1ps

module vaes_regfile (
	input  logic         clk,
	input  logic         rst_n,
	input  logic         we,
	input  logic [4:0]   waddr,
	input  logic [127:0] wdata,
	input  logic [4:0]   raddr_a,
	output logic [127:0] rdata_a,
	input  logic [4:0]   raddr_b,
	output logic [127:0] rdata_b
	);

	logic [127:0] mem [0:31];
	integer i;

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
		for (i = 0; i < 32; i++) begin
			mem[i] <= '0;
		end
		end
		else if (we) begin
		mem[waddr] <= wdata;
		end
	end

	assign rdata_a = mem[raddr_a];
	assign rdata_b = mem[raddr_b];

endmodule
