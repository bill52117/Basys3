`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NTHU
// Engineer: Y.J Shih
// 
// Create Date: 2015/05/27 11:15:54
// Design Name: Mouse Controller
// Module Name: MouseCtl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//  Original VHDL version is create by Ulrich Zolt.
// 
//////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////
// mouse_controller.vhd
////////////////////////////////////////////////////////////////////////
// Author : Ulrich Zolt
//          Copyright 2006 Digilent, Inc.
////////////////////////////////////////////////////////////////////////
// This file contains a controller for a ps/2 compatible mouse device.
// This controller uses the ps2interface module.
////////////////////////////////////////////////////////////////////////
//  Behavioral description
////////////////////////////////////////////////////////////////////////
// Please read the following article on the web for understanding how
// to interface a ps/2 mouse:
// http://www.computer/engineering.org/ps2mouse/

// This controller is implemented as described in the above article.
// The mouse controller receives bytes from the ps2interface which, in
// turn, receives them from the mouse device. Data is received on the
// rx_data input port, and is validated by the read signal. read is
// active for one clock period when new byte available on rx_data. Data
// is sent to the ps2interface on the tx_data output port and validated
// by the write output signal. 'write' should be active for one clock
// period when tx_data contains the command or data to be sent to the
// mouse. ps2interface wraps the byte in a 11 bits packet that is sent
// through the ps/2 port using the ps/2 protocol. Similarly, when the
// mouse sends data, the ps2interface receives 11 bits for every byte,
// extracts the byte from the ps/2 frame, puts it on rx_data and
// activates read for one clock period. If an error occurs when sending
// or receiving a frame from the mouse, the err input goes high for one
// clock period. When this occurs, the controller enters reset state.

// When in reset state, the controller resets the mouse and begins an
// initialization procedure that consists of tring to put mouse in
// scroll mode (enables wheel if the mouse has one), setting the
// resolution of the mouse, the sample rate and finally enables
// reporting. Implicitly the mouse, after a reset or imediately after a
// reset, does not send data packets on its own. When reset(or power/up)
// the mouse enters reset state, where it performs a test, called the
// bat test (basic assurance test), when this test is done, it sends
// the result: AAh for test ok, FCh for error. After this it sends its
// ID which is 00h. When this is done, the mouse enters stream mode,
// but with reporting disabled (movement data packets are not sent).
// To enable reporting the enable data reporting command (F4h) must be
// sent to the mouse. After this command is sent, the mouse will send
// movement data packets when the mouse is moved or the status of the
// button changes.

// After sending a command or a byte following a command, the mouse
// must respond with ack (FAh). For managing the intialization
// procedure and receiving the movement data packets, a FSM is used.
// When the fpga is powered up or the logic is reset using the global
// reset, the FSM enters reset state. From this state, the FSM will
// transition to a series of states used to initialize the mouse. When
// initialization is complete, the FSM remains in state read_byte_1,
// waiting for a movement data packet to be sent. This is the idle
// state if the FSM. When a byte is received in this state, this is
// the first byte of the 3 bytes sent in a movement data packet (4 bytes
// if mouse in scrolling mode). After reading the last byte from the
// packet, the FSM enters mark_new_event state and sets new_event high.
// After that FSM enterss read_byte_1 state, resets new_event and waits
// for a new packet.
// After a packet is received, new_event is set high for one clock
// period to "inform" the clients of this controller a new packet was
// received and processed.

// During the initialization procedure, the controller tries to put the
// mouse in scroll mode (activates wheel, if mouse has one). This is
// done by successively setting the sample rate to 200, then to 100, and
// lastly to 80. After this is done, the mouse ID is requested by 
// sending get device ID command (F2h). If the received ID is 00h than
// the mouse does not have a wheel. If the received ID is 03h than the
// mouse is in scroll mode, and when sending movement data packets
// (after enabling data reporting) it will include z movement data.
// If the mouse is in normal, non/scroll mode, the movement data packet
// consists of 3 successive bytes. This is their format:
//
//
//
// bits      7     6     5     4     3     2     1     0
//        -------------------------------------------------
// byte 1 | YOVF| XOVF|YSIGN|XSIGN|  1  | MBTN| RBTN| LBTN|
//        -------------------------------------------------
//        -------------------------------------------------
// byte 2 |                  X MOVEMENT                   |
//        -------------------------------------------------
//        -------------------------------------------------
// byte 3 |                  Y MOVEMENT                   |
//        -------------------------------------------------
// OVF = overflow
// BTN = button
// M = middle
// R = right
// L = left
//
// When scroll mode is enabled, the mouse send 4 byte movement packets.
// bits      7     6     5     4     3     2     1     0
//        -------------------------------------------------
// byte 1 | YOVF| XOVF|YSIGN|XSIGN|  1  | MBTN| RBTN| LBTN|
//        -------------------------------------------------
//        -------------------------------------------------
// byte 2 |                  X MOVEMENT                   |
//        -------------------------------------------------
//        -------------------------------------------------
// byte 3 |                  Y MOVEMENT                   |
//        -------------------------------------------------
//        -------------------------------------------------
// byte 4 |                  Z MOVEMENT                   |
//        -------------------------------------------------
// x and y movement counters are represented on 8 bits, 2's complement
// encoding. The first bit (sign bit) of the counters are the xsign and
// ysign bit from the first packet, the rest of the bits are the second
// byte for the x movement and the third byte for y movement. For the
// z movement the range is -8 -> +7 and only the 4 least significant
// bits from z movement are valid, the rest are sign extensions.
// The x and y movements are in range: -256 -> +255
//
// The mouse uses as axes origin the lower-left corner. For the purpose
// of displaying a mouse cursor on the screen, the controller inverts
// the y axis to move the axes origin in the upper-left corner. This
// is done by negating the y movement value (following the 2s complement
// encoding). The movement data received from the mouse are delta
// movements, the data represents the movement of the mouse relative
// to the last position. The controller keeps track of the position of
// the mouse relative to the upper-left corner. This is done by keeping
// the mouse position in two registers x_pos and y_pos and adding the
// delta movements to their value. The addition uses saturation. That
// means the value of the mouse position will not exceed certain bounds
// and will not rollover the a margin. For example, if the mouse is at
// the left margin and is moved left, the x position remains at the left
// margin(0). The lower bound is always 0 for both x and y movement.
// The upper margin can be set using input pins: value, setmax_x,
// setmax_y. To set the upper bound of the x movement counter, the new
// value is placed on the value input pins and setmax_x is activated
// for at least one clock period. Similarly for y movement counter, but
// setmax_y is activated instead. Notice that value has 10 bits, and so
// the maximum value for a bound is 1023.
//
// The position of the mouse (x_pos and y_pos) can be set at any time,
// by placing the x or y position on the value input pins and activating
// the setx, or sety respectively, for at least one clock period. This
// is useful for setting an original position of the mouse different
// from (0,0).
////////////////////////////////////////////////////////////////////////
//  Port definitions
////////////////////////////////////////////////////////////////////////
// clk            - global clock signal (100MHz)
// rst            - global reset signal
// xpos           - output pin, 10 bits
//                - the x position of the mouse relative to the upper
//                - left corner
// ypos           - output pin, 10 bits
//                - the y position of the mouse relative to the upper
//                - left corner
// zpos           - output pin, 4 bits
//                - last delta movement on z axis
// left           - output pin, high if the left mouse button is pressed
// middle         - output pin, high if the middle mouse button is
//                - pressed
// right          - output pin, high if the right mouse button is
//                - pressed
// new_event      - output pin, active one clock period after receiving
//                - and processing one movement data packet.
////////////////////////////////////////////////////////////////////////
// Revision History:
// 09/18/2006(UlrichZ): created
////////////////////////////////////////////////////////////////////////

module MouseCtl #(
  parameter SYSCLK_FREQUENCY_HZ            = 100000000,
  parameter CHECK_PERIOD_MS                = 500, // Period in miliseconds to check if the mouse is present
  parameter TIMEOUT_PERIOD_MS              = 100, // Timeout period in miliseconds when the mouse presence is checked
  parameter HORIZONTAL_WIDTH               = 1280,
  parameter VERTICAL_WIDTH                 = 1024
)(
  clk,     
  rst,     
  xpos,    
  ypos,    
  zpos,    
  left,    
  middle,  
  right,   
  new_event,
  value,   
  setx,    
  sety,    
  setmax_x,
  setmax_y,
  
  ps2_clk, 
  ps2_data
);
  input clk, rst;
  output reg [11:0] xpos, ypos;
  output reg [3:0] zpos;
  output reg left, middle, right, new_event;
  input [11:0] value;
  input setx, sety, setmax_x, setmax_y;
  
  inout ps2_clk, ps2_data;
  
  // function called clogb2 that returns an integer which has the 
  // value of the ceiling of the log base 2.                      
  function integer clogb2 (input integer bit_depth);              
  begin                                                           
    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
      bit_depth = bit_depth >> 1;                                 
    end                                                           
  endfunction
  
  parameter CHECK_PERIOD_CLOCK = ((CHECK_PERIOD_MS*1000000)/(1000000000/SYSCLK_FREQUENCY_HZ));
  parameter TIMEOUT_PERIOD_CLOCK = ((TIMEOUT_PERIOD_MS*1000000)/(1000000000/SYSCLK_FREQUENCY_HZ));
  parameter MAX_CLOCK = (CHECK_PERIOD_CLOCK > TIMEOUT_PERIOD_CLOCK)?CHECK_PERIOD_CLOCK:TIMEOUT_PERIOD_CLOCK;
  parameter COUNTER_WIDTH = clogb2(MAX_CLOCK-1);
  
  parameter DEFAULT_MAX_X = HORIZONTAL_WIDTH;
  parameter DEFAULT_MAX_Y = VERTICAL_WIDTH;
  
  parameter RESET                    = 4'd0;
  parameter SEND_CMD                 = 4'd1;
  parameter WAIT_ACK                 = 4'd2;
  parameter RESET_WAIT_BAT           = 4'd3;
  parameter RESET_WAIT_ID            = 4'd4;
  parameter WAIT_DEVICE_ID           = 4'd5;
  parameter READ_BYTE_1              = 4'd6;
  parameter READ_BYTE_2              = 4'd7;
  parameter READ_BYTE_3              = 4'd8;
  parameter READ_BYTE_4              = 4'd9;
  parameter CHECK_DEVICE_ID          = 4'd10;
  parameter CHECK_DEVICE_ID_WAIT_ACK = 4'd11;
  parameter CHECK_DEVICE_ID_WAIT_ID  = 4'd12;
  
  parameter [7:0] CMD_RESET = 8'hFF;
  parameter [7:0] CMD_SET_SAMPLE_RATE = 8'hF3;
  parameter [7:0] CMD_GET_DEVICE_ID = 8'hF2;
  parameter [7:0] CMD_SET_RESOLUTION = 8'hE8;
  parameter [7:0] CMD_ENABLE_DATA_REPORTING = 8'hF4;
  
  parameter [7:0] RSP_ACK = 8'hFA;
  parameter [7:0] RSP_BAT_OK = 8'hAA;
  parameter [7:0] RSP_ID_0 = 8'h00;
  parameter [7:0] RSP_ID_3 = 8'h03;
  
  parameter COMMAND_LENGHT = 13;
  parameter [7:0] COMMAND_LIST [0:COMMAND_LENGHT-1] = {
    CMD_RESET,
    CMD_SET_SAMPLE_RATE,
	8'hC8,    // set sample rate = 200
	CMD_SET_SAMPLE_RATE,
	8'h64,    // set sample rate = 100
	CMD_SET_SAMPLE_RATE,
	8'h50,    // set sample rate = 80
	CMD_GET_DEVICE_ID,
	CMD_SET_RESOLUTION,
	8'h03,    // resolution = 8 count/mm
	CMD_SET_SAMPLE_RATE,
	8'h28,    //  set sample rate = 40
	CMD_ENABLE_DATA_REPORTING
  };
  parameter COMMAND_COUNTER_WIDTH = clogb2(COMMAND_LENGHT-1);
  
  
  // Periodic checking counter, reset and tick signal, and
  // Timeout checking counter, reset and timeout indication signal
  // The periodic checking counter acts as a watchdog, periodically
  // reading the Mouse ID, therefore checking if the mouse is present
  // If there is no answer, after the timeout period passed, then the
  // state machine is reinitialized
  reg [COUNTER_WIDTH-1:0] counter;
  wire periodic_check_tick, timeout_tick;
  reg counter_reset, counter_start;
  
  // program counter for mouse initialization
  reg [COMMAND_COUNTER_WIDTH-1:0] pc;
  reg pc_reset, pc_count;
  
  reg [11:0] ymax, xmax;
  
  
  
  // horizontal and veritcal mouse position
  // origin of axes is upper-left corner
  // the origin of axes the mouse uses is the lower-left corner
  // The y-axis is inverted, by making negative the y movement received
  // from the mouse (if it was positive it becomes negative
  // and vice versa)
  reg [11:0] xpos_inter, xpos_next;
  reg [11:0] ypos_inter, ypos_next;
  
  reg [3:0] state, state_next;
  reg haswheel, haswheel_next;
  reg x_overflow, x_overflow_next;
  reg y_overflow, y_overflow_next;
  reg x_sign, x_sign_next;
  reg y_sign, y_sign_next;
  reg [7:0] tx_data;
  reg tx_valid;
  reg [7:0] x_inc, y_inc;
  
  wire [7:0] rx_data;
  wire rx_valid;
  wire ps2_busy;
  wire ps2_err;
  
  // counter for periodic check and time-out
  assign periodic_check_tick = (counter >= CHECK_PERIOD_CLOCK-1)?1'b1:1'b0;
  assign timeout_tick = (counter >= TIMEOUT_PERIOD_CLOCK-1)?1'b1:1'b0;
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  counter <= 0;
	else if(counter_reset == 1'b1 || counter == MAX_CLOCK-1)
	  counter <= 0;
	else if(counter_start == 1'b1)
	  counter <= counter + 1'b1;
	else 
	  counter <= counter;
  end
  
  // program counter for COMMAND_LIST
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  pc <= 0;
	else if(pc_reset == 1'b1)
	  pc <= 0;
	else if(pc_count == 1'b1 && pc < COMMAND_LENGHT )
	  pc <= pc + 1'b1;
	else
	  pc <= pc;
  end
  
  //************* output registers ****************//
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  xpos <= 0;
	else if(setx == 1'b1)
	  xpos <= value;
	else
	  xpos <= xpos_next;
  end
  
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  ypos <= 0;
	else if(sety == 1'b1)
	  ypos <= value;
	else
	  ypos <= ypos_next;
  end
  
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  zpos <= 'b0;
	else if(state == READ_BYTE_4 && rx_valid == 1'b1)
	  zpos <= rx_data[3:0];
	else
	  zpos <= zpos;
  end
  
  always @ (posedge clk, posedge rst)begin
    if(rst)begin
	  {middle, right, left} <= 'b0;
	end else if(state == READ_BYTE_1 && rx_valid == 1'b1)begin
	  {middle, right, left} <= rx_data[2:0];
	end else begin
	  {middle, right, left} <= {middle, right, left};
	end
  end
  
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  new_event <= 1'b0;
	else if(haswheel == 1'b0 && state == READ_BYTE_3 && rx_valid == 1'b1)
	  new_event <= 1'b1;
	else if(haswheel == 1'b1 && state == READ_BYTE_4 && rx_valid == 1'b1)
	  new_event <= 1'b1;
	else
	  new_event <= 1'b0;
  end
  
  //************* x, y max register ****************//
  
  // sets the maximum value of the x movement register, stored in xmax
  // when setmax_x is active, max value should be on value input pin
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  xmax <= HORIZONTAL_WIDTH;
	else if(setmax_x == 1'b1)
	  xmax <= value;
	else
	  xmax <= xmax;
  end
	 
  // sets the maximum value of the y movement register, stored in ymax
  // when setmax_y is active, max value should be on value input pin	 
  always @ (posedge clk, posedge rst)begin
    if(rst)
	  ymax <= VERTICAL_WIDTH;
	else if(setmax_y == 1'b1)
	  ymax <= value;
	else
	  ymax <= ymax;
  end
  
  //***************** x, y position count *******************//
  always @ * begin
    if(state == READ_BYTE_2 && rx_valid == 1'b1)begin
	  if(x_sign == 1'b1)begin
	    if(x_overflow == 1'b1)begin
		  xpos_inter = xpos + (-12'd256);
		end else begin
		  xpos_inter = xpos + {4'b1111, x_inc};
		end
		
		// xpos_inter underflow
		if(xpos_inter[11] == 1'b1)begin
		  xpos_next = 0;
		end else begin
		  xpos_next = xpos_inter;
		end
	  end else begin
	    if(x_overflow == 1'b1)begin
		  xpos_inter = xpos + 12'd256;
		end else begin
		  xpos_inter = xpos + {4'b0000, x_inc};
		end
		
		if(xpos_inter > xmax)begin
		  xpos_next = xmax;
		end else begin
		  xpos_next = xpos_inter;
		end
	  end
	end else begin
	  xpos_inter = xpos;
	  xpos_next = xpos;
	end
  end
  
  always @ * begin
    if(state == READ_BYTE_3 && rx_valid == 1'b1)begin
	  if(y_sign == 1'b1)begin
	    //Note: axes origin is upper-left corner
		if(y_overflow == 1'b1)begin
		  ypos_inter = ypos + 12'd256;
		end else begin
		  ypos_inter = ypos + ((~{4'b1111, y_inc}) + 1'b1);
		end
		
		if(ypos_inter[11] == 1'b1)begin
		  ypos_next = 0;
		end else begin
		  ypos_next = ypos_inter;
		end
	  end else begin
	    if(y_overflow == 1'b1)begin
		  ypos_inter = ypos + (-12'd256);
		end else begin
		  ypos_inter = ypos + ((~{4'b0000, y_inc}) + 1'b1);
		end
		
		if(ypos_inter > ymax)begin
		  ypos_next = ymax;
		end else begin
		  ypos_next = ypos_inter;
		end
	  end
	end else begin
	  ypos_inter = ypos;
	  ypos_next = ypos;
	end
  end
  
  // DFF for FSM
  always @ (posedge clk, posedge rst)begin
    if(rst)begin
	  state <= RESET;
	  haswheel <= 1'b0;
	  x_overflow <= 1'b0;
	  y_overflow <= 1'b0;
	  x_sign <= 1'b0;
	  y_sign <= 1'b0;
	end else begin
	  state <= state_next;
	  haswheel <= haswheel_next;
	  x_overflow <= x_overflow_next;
	  y_overflow <= y_overflow_next;
	  x_sign <= x_sign_next;
	  y_sign <= y_sign_next;
	end
  end
  
  //****************** FSM *******************//
  always @ * begin
    state_next = RESET;
	haswheel_next = haswheel;
	x_overflow_next = x_overflow;
	y_overflow_next = y_overflow;
	x_sign_next = x_sign;
	y_sign_next = y_sign;
	tx_data = 'b0;
	tx_valid = 1'b0;
	counter_reset = 1'b0;
	counter_start = 1'b0;
	pc_reset = 1'b0;
	pc_count = 1'b0;
	x_inc = 8'b0;
	y_inc = 8'b0;
	case(state)
	  RESET:begin
	      haswheel_next = 1'b0;
		  x_overflow_next = 1'b0;
		  y_overflow_next = 1'b0;
		  x_sign_next = 1'b0;
		  y_sign_next = 1'b0;
		  counter_reset = 1'b1;
		  pc_reset = 1'b1;
		  state_next = SEND_CMD;
	    end
		
	  SEND_CMD:begin
	      tx_data = COMMAND_LIST[pc];
		  tx_valid = 1'b1;
		  if(ps2_busy == 1'b0)begin
		    state_next = WAIT_ACK;
	      end else begin
		    state_next = SEND_CMD;
		  end
	    end
	
	  WAIT_ACK:begin
	      if(rx_valid == 1'b1 && rx_data == RSP_ACK)begin
		    pc_count = 1'b1;
		    if(COMMAND_LIST[pc] == CMD_RESET)begin
			  state_next = RESET_WAIT_BAT;
			end else if(COMMAND_LIST[pc] == CMD_GET_DEVICE_ID)begin
			  state_next = WAIT_DEVICE_ID;
			end else if(COMMAND_LIST[pc] == CMD_ENABLE_DATA_REPORTING)begin
			  counter_reset = 1'b1;
			  state_next = READ_BYTE_1;
			end else begin
			  state_next = SEND_CMD;
			end
		  end else if(rx_valid == 1'b1)begin
		    state_next = RESET;
	      end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = WAIT_ACK;
		  end
	    end
		
	  RESET_WAIT_BAT:begin
	      if(rx_valid == 1'b1)begin
		    if(rx_data == RSP_BAT_OK)begin
			  state_next = RESET_WAIT_ID;
			end else begin
			  state_next = RESET;
			end
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
	      end else begin
		    state_next = RESET_WAIT_BAT;
		  end
	    end
		
	  RESET_WAIT_ID:begin
	      if(rx_valid == 1'b1)begin
		    if(rx_data == RSP_ID_0)begin
			  state_next = SEND_CMD;
			end else begin
			  state_next = RESET;
			end
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = RESET_WAIT_ID;
		  end
		end
		
	  WAIT_DEVICE_ID:begin
	      if(rx_valid == 1'b1)begin
		    if(rx_data == RSP_ID_0)begin
			  haswheel_next = 1'b0;
			  state_next = SEND_CMD;
			end else if(rx_data == RSP_ID_3)begin
			  haswheel_next = 1'b1;
			  state_next = SEND_CMD;
			end else begin
			  state_next = RESET;
			end
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = WAIT_DEVICE_ID;
		  end
	    end
		
	  READ_BYTE_1:begin
	      counter_start = 1'b1;
		  if(rx_valid == 1'b1)begin
		    y_overflow_next = rx_data[7];
			x_overflow_next = rx_data[6];
			y_sign_next = rx_data[5];
			x_sign_next = rx_data[4];
			state_next = READ_BYTE_2;
		  end else if(periodic_check_tick == 1'b1)begin
		    state_next = CHECK_DEVICE_ID;
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = READ_BYTE_1;
		  end
	    end
		
	  READ_BYTE_2:begin
	      counter_start = 1'b1;
		  if(rx_valid == 1'b1)begin
		    state_next = READ_BYTE_3;
			x_inc = rx_data;
		  end else if(periodic_check_tick == 1'b1)begin
		    state_next = CHECK_DEVICE_ID;
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = READ_BYTE_2;
		  end
	    end
	
	  READ_BYTE_3:begin
	      counter_start = 1'b1;
		  if(rx_valid == 1'b1)begin
			y_inc = rx_data;
		    if(haswheel == 1'b0)begin
		      state_next = READ_BYTE_1;
			end else begin
			  state_next = READ_BYTE_4;
			end
		  end else if(periodic_check_tick == 1'b1)begin
		    state_next = CHECK_DEVICE_ID;
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = READ_BYTE_3;
		  end
	    end
	
	  READ_BYTE_4:begin
	      counter_start = 1'b1;
	      if(rx_valid == 1'b1)begin
		    state_next = READ_BYTE_1;
		  end else if(periodic_check_tick == 1'b1)begin
		    state_next = CHECK_DEVICE_ID;
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = READ_BYTE_4;
		  end
	    end
		
	  CHECK_DEVICE_ID:begin
	      counter_reset = 1'b1;
		  tx_data = CMD_GET_DEVICE_ID;
		  tx_valid = 1'b1;
		  if(ps2_busy == 1'b0)begin
		    state_next = CHECK_DEVICE_ID_WAIT_ACK;
		  end else begin
		    state_next = CHECK_DEVICE_ID;
		  end
	    end
		
	  CHECK_DEVICE_ID_WAIT_ACK:begin
	      counter_start = 1'b1;
	      if(rx_valid == 1'b1)begin
		    if(rx_data == RSP_ACK)begin
			  state_next = CHECK_DEVICE_ID_WAIT_ID;
			end else begin
			  state_next = RESET;
			end
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else if(timeout_tick == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = CHECK_DEVICE_ID_WAIT_ACK;
		  end
	    end
		
      CHECK_DEVICE_ID_WAIT_ID:begin
	      counter_start = 1'b1;
		  if(rx_valid == 1'b1)begin
		    if(rx_data == RSP_ID_0 || rx_data == RSP_ID_3)begin
			  counter_reset = 1'b1;
			  state_next = READ_BYTE_1;
			end else begin
			  state_next = RESET;
			end
		  end else if(ps2_err == 1'b1)begin
		    state_next = RESET;
		  end else if(timeout_tick == 1'b1)begin
		    state_next = RESET;
		  end else begin
		    state_next = CHECK_DEVICE_ID_WAIT_ID;
		  end
	    end
	endcase
  end
  
  Ps2Interface#(
    .SYSCLK_FREQUENCY_HZ(SYSCLK_FREQUENCY_HZ)
  ) Ps2Interface_i (
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    
    .clk(clk),
    .rst(rst),
    
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    
    .busy(ps2_busy),
    .err(ps2_err)
);
endmodule