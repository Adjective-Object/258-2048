module bars(input [9:0] x, input [9:0] y,
	output [9:0] red, output [9:0] green, output [9:0] blue);
reg [2:0] idx;
always @(x)
begin
	if (x < 80) idx <= 3'd0;
	else if (x < 160) idx <= 3'd1;
	else if (x < 240) idx <= 3'd2;
	else if (x < 320) idx <= 3'd3;
	else if (x < 400) idx <= 3'd4;
	else if (x < 480) idx <= 3'd5;
	else if (x < 560) idx <= 3'd6;
	else idx <= 3'd7;
end
assign red = (idx[0]? 10'h3ff: 10'h000);
assign green = (idx[1]? 10'h3ff: 10'h000);
assign blue = (idx[2]? 10'h3ff: 10'h000);

endmodule
