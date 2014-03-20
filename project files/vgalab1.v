module vgalab1(
//	Clock Input
  input CLOCK_50,	//	50 MHz
  input CLOCK_27,     //      27 MHz
//	Push Button
  input [3:0] KEY,      //	Pushbutton[3:0]
//	DPDT Switch
  input [17:0] SW,		//	Toggle Switch[17:0]
//	7-SEG Display
  output [6:0]	HEX0,HEX1,HEX2,HEX3,HEX4,HEX5,HEX6,HEX7,  // Seven Segment Digits
//	LED
  output [8:0]	LEDG,  //	LED Green[8:0]
  output [17:0] LEDR,  //	LED Red[17:0]
//	GPIO
 inout [35:0] GPIO_0,GPIO_1,	//	GPIO Connections
//	TV Decoder
//TD_DATA,    	//	TV Decoder Data bus 8 bits
//TD_HS,		//	TV Decoder H_SYNC
//TD_VS,		//	TV Decoder V_SYNC
  output TD_RESET,	//	TV Decoder Reset
// VGA
  output VGA_CLK,   						//	VGA Clock
  output VGA_HS,							//	VGA H_SYNC
  output VGA_VS,							//	VGA V_SYNC
  output VGA_BLANK,						//	VGA BLANK
  output VGA_SYNC,						//	VGA SYNC
  output [9:0] VGA_R,   						//	VGA Red[9:0]
  output [9:0] VGA_G,	 						//	VGA Green[9:0]
  output [9:0] VGA_B   						//	VGA Blue[9:0]
);

//	All inout port turn to tri-state
assign	GPIO_0		=	36'hzzzzzzzzz;
assign	GPIO_1		=	36'hzzzzzzzzz;

wire RST;
assign RST = KEY[0];

// reset delay gives some time for peripherals to initialize
wire DLY_RST;
Reset_Delay r0(	.iCLK(CLOCK_50),.oRESET(DLY_RST) );

// Send switches to red leds 
assign LEDR = SW;

// Turn off green leds
assign LEDG = 8'h00;

wire [6:0] blank = 7'b111_1111;

// blank unused 7-segment digits
assign HEX0 = blank;
assign HEX1 = blank;
assign HEX2 = blank;
assign HEX3 = blank;
assign HEX4 = blank;
assign HEX5 = blank;
assign HEX6 = blank;
assign HEX7 = blank;

wire		VGA_CTRL_CLK;
wire		AUD_CTRL_CLK;
wire [9:0]	mVGA_R;
wire [9:0]	mVGA_G;
wire [9:0]	mVGA_B;
wire [9:0]	mCoord_X;
wire [9:0]	mCoord_Y;

assign	TD_RESET = 1'b1; // Enable 27 MHz

VGA_Audio_PLL 	p1 (	
	.areset(~DLY_RST),
	.inclk0(CLOCK_27),
	.c0(VGA_CTRL_CLK),
	.c1(AUD_CTRL_CLK),
	.c2(VGA_CLK)
);


//------------------------------------------

reg [3:0] cout;
reg datagrid [3:0] [3:0] [5:0];
wire outstreams [3:0] [3:0] [3:0];

reg [2:0] i_x, i_y;

initial begin
	i_x = 0;
	repeat (4) begin
		i_y = 0;
		repeat (4) begin
			datagrid[i_x][i_y][0] <= 1;
			datagrid[i_x][i_y][1] <= 0;
			datagrid[i_x][i_y][2] <= 0;
			i_y = i_y + 1;
		end
		i_x = i_x + 1;
	end
end

parameter blockdim = 64;
parameter margins = 10;
parameter xoff = 40;
parameter yoff = 0;

genvar i;
generate
for(i=0; i<16; i=i+1) begin:blockgen
	block b(mCoord_X, mCoord_Y,
	
		xoff + margins + (blockdim + margins)*(i/4),
		
		yoff + margins + (blockdim + margins)*(i%4),
		
		blockdim,
		
		1,
		
		{outstreams[(i/4)][(i%4)][2],
			outstreams[(i/4)][(i%4)][1],
			outstreams[(i/4)][(i%4)][0],
		});
end
endgenerate

reg [6:0] count;
always begin
	count <= 0;
	cout = 0;
	repeat (4) begin
		repeat (4) begin
			if(
				{outstreams[i_x][i_y][2],
					outstreams[i_x][i_y][1],
					outstreams[i_x][i_y][0]} != 0) begin
				count <= count+1;
				cout = cout | {outstreams[i_x][i_y][2],
					outstreams[i_x][i_y][1],
					outstreams[i_x][i_y][0]};
			end
			i_y = i_y + 1;
		end
		i_x = i_x + 1;
	end
	
	if(count == 0) begin
		cout = 0;
	end
	
end

color_blocker colorer(
					mVGA_R,
					mVGA_G,
					mVGA_B,
					cout);

//------------------------------------------


vga_sync u1(
   .iCLK(VGA_CTRL_CLK),
   .iRST_N(DLY_RST&KEY[0]),	
   .iRed(mVGA_R),
   .iGreen(mVGA_G),
   .iBlue(mVGA_B),
   // pixel coordinates
   .px(mCoord_X),
   .py(mCoord_Y),
   // VGA Side
   .VGA_R(VGA_R),
   .VGA_G(VGA_G),
   .VGA_B(VGA_B),
   .VGA_H_SYNC(VGA_HS),
   .VGA_V_SYNC(VGA_VS),
   .VGA_SYNC(VGA_SYNC),
   .VGA_BLANK(VGA_BLANK)
);

endmodule

// THIS TOO

module block(
	input [9:0] x,
	input [9:0] y,
	input [9:0] x_off,
	input [9:0] y_off,
	input [9:0] dim,
	input [3:0] value,
	output reg [3:0] pxout
);
	
	reg [9:0] rx, ry;
	
	always@(x or y or x_off or y_off or dim or value) begin
		if (x>x_off && y>y_off && x<x_off+dim && y<y_off+dim) begin
			pxout <= value;
		end else begin
			pxout <= 0;
		end
	end

endmodule

module color_blocker(
						output [9:0] r,
						output [9:0] g,
						output [9:0] b,
						input [3:0] color_class);
		reg [9:0] v1, v2, v3;
		
		always begin
			case (color_class)
				0:begin
					v1= 10'h000;
					v2= 10'h000;
					v3= 10'h000;
				end
				1:begin
					v1= 10'h000;
					v2= 10'hFFF;
					v3= 10'hFFF;
				end
				2:begin
					v1= 10'hFFF;
					v2= 10'h000;
					v3= 10'hFFF;
				end
				3:begin
					v1= 10'hFFF;
					v2= 10'hFFF;
					v3= 10'h000;
				end
				4:begin
					v1= 10'h000;
					v2= 10'h000;
					v3= 10'hFFF;
				end
			endcase
		end
		
		assign r = v1;
		assign g = v2;
		assign b = v3;
		
endmodule
