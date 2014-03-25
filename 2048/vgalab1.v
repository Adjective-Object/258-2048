module vgalab1(
//	Clock Input
  input    PS2_DAT,
  input    PS2_CLK,
  input CLOCK_50,	//	50 MHz
  input CLOCK_27,     //      27 MHz
//	Push Button
  input [3:0] KEY,      //	Pushbutton[3:0]
//	DPDT Switch
  input [17:0] SW,		//	Toggle Switch[17:0]
  output [8:0]	LEDG,  //	LED Green[8:0]
  output [17:0] LEDR,  //	LED Red[17:0]
//	GPIO

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


wire RST;
assign RST = KEY[0];

// reset delay gives some time for peripherals to initialize
wire DLY_RST;
Reset_Delay r0(	.iCLK(CLOCK_50),.oRESET(DLY_RST) );

// Turn off green leds
wire		VGA_CTRL_CLK;
wire		AUD_CTRL_CLK;
wire [9:0]	mVGA_R;
wire [9:0]	mVGA_G;
wire [9:0]	mVGA_B;
wire [9:0]	mCoord_X;
wire [9:0]	mCoord_Y;

assign	TD_RESET = 1'b1; // Enable 27 MHz

//keyboard//
wire reset = 1'b0;
wire [7:0] scan_code;
reg [7:0] history[1:4];
wire read, scan_ready;
//keyboard//


VGA_Audio_PLL 	p1 (	
	.areset(~DLY_RST),
	.inclk0(CLOCK_27),
	.c0(VGA_CTRL_CLK),
	.c1(AUD_CTRL_CLK),
	.c2(VGA_CLK)
);

reg [3:0] cout;
reg datagrid [3:0] [3:0] [5:0];
wire outstreams [3:0] [3:0] [3:0];

//initialize at blank grid
reg [5:0] i_x, i_y;
initial begin
	i_x = 0;
	repeat (4) begin
		i_y = 0;
		repeat (4) begin
			{datagrid[i_x][i_y][5],
			datagrid[i_x][i_y][4],
			datagrid[i_x][i_y][3],
			datagrid[i_x][i_y][2],
			datagrid[i_x][i_y][1],
			datagrid[i_x][i_y][0]} <= 1;
			i_y = i_y + 1;
		end
		i_x = i_x + 1;
	end
end
//end initialization

//begin controls
reg[2:0] XXX = 1,YYY = 1; 

always @ (negedge KEY[3]) begin
	XXX = XXX+1;
	if (XXX > 3)
		XXX <= 0;
end

always @ (negedge KEY[2]) begin
	YYY = YYY+1;
	if (YYY > 3)
		YYY <= 0;
end

always @ (SW[5:0]) begin
	{datagrid[XXX][YYY][5],
			datagrid[XXX][YYY][4],
			datagrid[XXX][YYY][3],
			datagrid[XXX][YYY][2],
			datagrid[XXX][YYY][1],
			datagrid[XXX][YYY][0]} = SW[5:0];
end

assign LEDG[0] = (scan_code == 8'h6B);
assign LEDG[1] = (scan_code == 8'h72);
assign LEDG[2] = (scan_code == 8'h74);
assign LEDG[3] = (scan_code == 8'h75);

assign LEDR[17:14] = scan_code[7:4];
assign LEDR[13:10] = scan_code[3:0];

assign LEDR [2:0] = XXX;
assign LEDR [6:4] = YYY;
//end controls



parameter blockdim = 100;
parameter margins = 10;
parameter xoff = 100;
parameter yoff = 18;
parameter rectangle_radius = 3;

genvar g_x, g_y;
generate
for(g_x=0; g_x<4; g_x=g_x+1) begin:outer
	for(g_y=0; g_y<4; g_y=g_y + 1)begin:inner
		block b(mCoord_X, mCoord_Y,
		
			xoff + margins + (blockdim + margins)*(g_x),
			
			yoff + margins + (blockdim + margins)*(g_y),
			
			blockdim, rectangle_radius,
			
			{datagrid[g_x][g_y][5],
				datagrid[g_x][g_y][4],
				datagrid[g_x][g_y][3],
				datagrid[g_x][g_y][2],
				datagrid[g_x][g_y][1],
				datagrid[g_x][g_y][0]},
			
			{outstreams[g_x][g_y][2],
				outstreams[g_x][g_y][1],
				outstreams[g_x][g_y][0]}
		);
	end
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


//--------Keyboard------------


oneshot pulser(
   .pulse_out(read),
   .trigger_in(scan_ready),
   .clk(CLOCK_50)
);

keyboard kbd(
  .keyboard_clk(PS2_CLK),
  .keyboard_data(PS2_DAT),
  .clock50(CLOCK_50),
  .reset(reset),
  .read(read),
  .scan_ready(scan_ready),
  .scan_code(scan_code)
);

always @(posedge scan_ready)
begin
    history[4] <= history[3];
    history[3] <= history[2];
    history[2] <= history[1];
    history[1] <= scan_code;
end
//------------Keyboard-----------------



endmodule

// THIS TOO

module block(
	input [9:0] x,
	input [9:0] y,
	input [9:0] x_off,
	input [9:0] y_off,
	input [9:0] dim, input[9:0] radius,
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

module keyboard(keyboard_clk, keyboard_data, clock50, reset, read, scan_ready, scan_code);
input keyboard_clk;
input keyboard_data;
input clock50; // 50 Mhz system clock
input reset;
input read;
output scan_ready;
output [7:0] scan_code;
reg ready_set;
reg [7:0] scan_code;
reg scan_ready;
reg read_char;
reg clock; // 25 Mhz internal clock

reg [3:0] incnt;
reg [8:0] shiftin;

reg [7:0] filter;
reg keyboard_clk_filtered;

// scan_ready is set to 1 when scan_code is available.
// user should set read to 1 and then to 0 to clear scan_ready

always @ (posedge ready_set or posedge read)
if (read == 1) scan_ready <= 0;
else scan_ready <= 1;

// divide-by-two 50MHz to 25MHz
always @(posedge clock50)
    clock <= ~clock;



// This process filters the raw clock signal coming from the keyboard 
// using an eight-bit shift register and two AND gates

always @(posedge clock)
begin
   filter <= {keyboard_clk, filter[7:1]};
   if (filter==8'b1111_1111) keyboard_clk_filtered <= 1;
   else if (filter==8'b0000_0000) keyboard_clk_filtered <= 0;
end


// This process reads in serial data coming from the terminal

always @(posedge keyboard_clk_filtered)
begin
   if (reset==1)
   begin
      incnt <= 4'b0000;
      read_char <= 0;
   end
   else if (keyboard_data==0 && read_char==0)
   begin
    read_char <= 1;
    ready_set <= 0;
   end
   else
   begin
       // shift in next 8 data bits to assemble a scan code    
       if (read_char == 1)
           begin
              if (incnt < 9) 
              begin
                incnt <= incnt + 1'b1;
                shiftin = { keyboard_data, shiftin[8:1]};
                ready_set <= 0;
            end
        else
            begin
                incnt <= 0;
                scan_code <= shiftin[7:0];
                read_char <= 0;
                ready_set <= 1;
            end
        end
    end
end

endmodule

module oneshot(output reg pulse_out, input trigger_in, input clk);
reg delay;

always @ (posedge clk)
begin
    if (trigger_in && !delay) pulse_out <= 1'b1;
    else pulse_out <= 1'b0;
    delay <= trigger_in;
end 
endmodule
