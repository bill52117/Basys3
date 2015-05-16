`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////
// Module Name: vga
/////////////////////////////////////////////////////////////////

module vga #(
    parameter [1:0] TYPE = 0      // 0=VGA, 1=SVGA, 2=XGA, 3=SXGA
 )
 (
    input wire pclk,reset,
    output wire hsync,vsync,valid,
    output wire [10:0]h_cnt,
    output wire [9:0]v_cnt
    );
    
    reg [10:0]pixel_cnt;
    reg [10:0]line_cnt;
    reg hsync_i,vsync_i,hactive,vactive, hsync_default, vsync_default;
    integer HD, HF, HA, HB, HT, VD, VF, VA, VB, VT;
    
    always @(TYPE)
    case(TYPE)
      2'b00  : begin
                  HD = 640;
                  HF = 16;
                  HA = 96;
                  HB = 48;
                  HT = 800; //
                  VD = 480;
                  VF = 10;
                  VA = 2;
                  VB = 33;
                  VT = 525;
                  hsync_default = 1'b1;
                  vsync_default = 1'b1;
             end
      2'b01  : begin
                  HD = 800;
                  HF = 40;
                  HA = 128;
                  HB = 88;
                  HT = 1056;
                  VD = 600;
                  VF = 1;
                  VA = 4;
                  VB = 23;
                  VT = 628;
                  hsync_default = 1'b0;
                  vsync_default = 1'b0;
             end
      2'b10  : begin
                  HD = 1024;
                  HF = 24;
                  HA = 136;
                  HB = 160;
                  HT = 1344;
                  VD = 768;
                  VF = 3;
                  VA = 6;
                  VB = 29;
                  VT = 806;
                  hsync_default = 1'b1;
                  vsync_default = 1'b1;
             end
      2'b11  : begin
                  HD = 1280;
                  HF = 48;
                  HA = 112;
                  HB = 248;
                  HT = 1688;
                  VD = 1024;
                  VF = 1;
                  VA = 3;
                  VB = 38;
                  VT = 1066;
                  hsync_default = 1'b0;
                  vsync_default = 1'b0;
             end
      default: begin
                  HD = 640;
                  HF = 16;
                  HA = 96;
                  HB = 48;
                  HT = 800;
                  VD = 480;
                  VF = 10;
                  VA = 2;
                  VB = 33;
                  VT = 525;      
                  hsync_default = 1'b1;
                  vsync_default = 1'b1;       
              end
    endcase

    always@(posedge pclk)
        if(reset)
            pixel_cnt <= 0;
        else if(pixel_cnt < (HT - 1))
                pixel_cnt <= pixel_cnt + 1;
             else
                pixel_cnt <= 0;

    always@(posedge pclk)
        if(reset)
            hsync_i <= hsync_default;
        else if((pixel_cnt >= (HD + HF - 1))&&(pixel_cnt < (HD + HF + HA - 1)))
                hsync_i <= ~hsync_default;
            else
                hsync_i <= hsync_default; 
    
    always@(posedge pclk)
        if(reset)
            line_cnt <= 0;
        else if(pixel_cnt == (HT -1))
                if(line_cnt < (VT - 1))
                    line_cnt <= line_cnt + 1;
                else
                    line_cnt <= 0;
                    
    always@(posedge pclk)
        if(reset)
            vsync_i <= vsync_default; 
        else if((line_cnt >= (VD + VF - 1))&&(line_cnt < (VD + VF + VA - 1)))
            vsync_i <= ~vsync_default; 
        else
            vsync_i <= vsync_default; 
                    
    assign hsync = hsync_i;
    assign vsync = vsync_i;
    assign valid = ((pixel_cnt < HD) && (line_cnt < VD));
    
    assign h_cnt = (pixel_cnt < HD) ? pixel_cnt:11'd0;
    assign v_cnt = (line_cnt < VD) ? line_cnt[9:0]:10'd0;
           
endmodule
