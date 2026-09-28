//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
        //Master input clock
        input	      CLK_50M,

        //Async reset from top-level module.
        //Can be used as initial reset.
        input	      RESET,

        //Must be passed to hps_io module
        inout [48:0]  HPS_BUS,

        //Base video clock. Usually equals to CLK_SYS.
        output        CLK_VIDEO,

        //Multiple resolutions are supported using different CE_PIXEL rates.
        //Must be based on CLK_VIDEO
        output        CE_PIXEL,

        //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
        //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
        output [12:0] VIDEO_ARX,
        output [12:0] VIDEO_ARY,

        output [7:0]  VGA_R,
        output [7:0]  VGA_G,
        output [7:0]  VGA_B,
        output        VGA_HS,
        output        VGA_VS,
        output        VGA_DE,      // = ~(VBlank | HBlank)
        output        VGA_F1,
        output [1:0]  VGA_SL,
        output        VGA_SCALER,  // Force VGA scaler
        output        VGA_DISABLE, // analog out is off

        input [11:0]  HDMI_WIDTH,
        input [11:0]  HDMI_HEIGHT,
        output        HDMI_FREEZE,
        output        HDMI_BLACKOUT,
        output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
        // Use framebuffer in DDRAM
        // FB_FORMAT:
        //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
        //    [3]   : 0=16bits 565 1=16bits 1555
        //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
        //
        // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
        output        FB_EN,
        output [4:0]  FB_FORMAT,
        output [11:0] FB_WIDTH,
        output [11:0] FB_HEIGHT,
        output [31:0] FB_BASE,
        output [13:0] FB_STRIDE,
        input         FB_VBL,
        input         FB_LL,
        output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
        // Palette control for 8bit modes.
        // Ignored for other video modes.
        output        FB_PAL_CLK,
        output [7:0]  FB_PAL_ADDR,
        output [23:0] FB_PAL_DOUT,
        input [23:0]  FB_PAL_DIN,
        output        FB_PAL_WR,
`endif
`endif

        output        LED_USER,    // 1 - ON, 0 - OFF.

        // b[1]: 0 - LED status is system status OR'd with b[0]
        //       1 - LED status is controled solely by b[0]
        // hint: supply 2'b00 to let the system control the LED.
        output [1:0]  LED_POWER,
        output [1:0]  LED_DISK,

        // I/O board button press simulation (active high)
        // b[1]: user button
        // b[0]: osd button
        output [1:0]  BUTTONS,

        input         CLK_AUDIO,   // 24.576 MHz
        output [15:0] AUDIO_L,
        output [15:0] AUDIO_R,
        output        AUDIO_S,     // 1 - signed audio samples, 0 - unsigned
        output [1:0]  AUDIO_MIX,   // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

        //ADC
        inout [3:0]   ADC_BUS,

        //SD-SPI
        output        SD_SCK,
        output        SD_MOSI,
        input         SD_MISO,
        output        SD_CS,
        input         SD_CD,

        //High latency DDR3 RAM interface
        //Use for non-critical time purposes
        output        DDRAM_CLK,
        input         DDRAM_BUSY,
        output [7:0]  DDRAM_BURSTCNT,
        output [28:0] DDRAM_ADDR,
        input [63:0]  DDRAM_DOUT,
        input         DDRAM_DOUT_READY,
        output        DDRAM_RD,
        output [63:0] DDRAM_DIN,
        output [7:0]  DDRAM_BE,
        output        DDRAM_WE,

        //SDRAM interface with lower latency
        output        SDRAM_CLK,
        output        SDRAM_CKE,
        output [12:0] SDRAM_A,
        output [1:0]  SDRAM_BA,
        inout [15:0]  SDRAM_DQ,
        output        SDRAM_DQML,
        output        SDRAM_DQMH,
        output        SDRAM_nCS,
        output        SDRAM_nCAS,
        output        SDRAM_nRAS,
        output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
        //Secondary SDRAM
        //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
        input         SDRAM2_EN,
        output        SDRAM2_CLK,
        output [12:0] SDRAM2_A,
        output [1:0]  SDRAM2_BA,
        inout [15:0]  SDRAM2_DQ,
        output        SDRAM2_nCS,
        output        SDRAM2_nCAS,
        output        SDRAM2_nRAS,
        output        SDRAM2_nWE,
`endif

        input         UART_CTS,
        output        UART_RTS,
        input         UART_RXD,
        output        UART_TXD,
        output        UART_DTR,
        input         UART_DSR,

        // Open-drain User port.
        // 0 - D+/RX
        // 1 - D-/TX
        // 2..6 - USR2..USR6
        // Set USER_OUT to 1 to read from USER_IN.
        input [6:0]   USER_IN,
        output [6:0]  USER_OUT,

        input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

   assign ADC_BUS  = 'Z;
   assign USER_OUT = '1;
   assign {UART_RTS, UART_TXD, UART_DTR} = 0;
   assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
   assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

   //assign VGA_SL = 0;
   assign VGA_F1 = 0;
   assign VGA_SCALER  = 0;
   assign VGA_DISABLE = 0;
   assign HDMI_FREEZE = 0;
   assign HDMI_BLACKOUT = 0;
   assign HDMI_BOB_DEINT = 0;

   assign AUDIO_S = 0;
   assign AUDIO_L = Sout;//L;
   assign AUDIO_R = Sout;//R;

   assign AUDIO_MIX = 0;

   assign LED_DISK = 0;
   assign LED_POWER = 0;
   assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

   wire ar = status[1];
   wire VertHorz = status[2];
   

   assign VIDEO_ARX =    ar ? 8'd16 : ( status[2] ? 8'd40 : 8'd30 );
   assign VIDEO_ARY =    ar ? 8'd9  : ( status[2] ? 8'd30 : 8'd40 );

   
   // Status Bitmap:
   // 0          1          2          3
   // 01234567890123456789012345678901
   // 0123456789ABCDEFGHIJKLMNOPQRSTUV
   // -AOfffi-------------------------
   
`include "build_id.v" 
   localparam CONF_STR = {
                          "RA_StarForce;;",
                          "-;",
                          "HFO1,Aspect Ratio,Original,Wide;",
                          "HFO2,Orientation,Vert,Horz;",
								  "O7,Flip Screen,Off,On;",
									"O8,Pause,Off,On;",
                          "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
                          "-;",
                          "DIP;",
                          "-;",
                          "O6,Invincibility,OFF,ON;",
                          "R[0],Reset and close OSD;",
                          "v,0;", // [optional] config version 0-99. 
                          // If CONF_STR options are changed in incompatible way, then change version number too,
                          // so all options will get default values on first start.
								  "J1,Fire,Start 1P,Coin,Pause,Start 2P;",
								  "jn,A,Start,Select,L,R;",
                          "V,v",`BUILD_DATE 
};

   wire       forced_scandoubler;
   wire [1:0] buttons;
   wire [127:0] status;
   wire [10:0]  ps2_key;
   wire         ioctl_download;
   wire         ioctl_wr;
   wire [24:0]  ioctl_addr;
   wire [7:0]   ioctl_dout;
   wire [7:0]   ioctl_index;
   wire [15:0]  joystk1, joystk2;
   wire         direct_video;
   wire         flip_screen;
   wire         rotate_ccw;
   wire         no_rotate = status[2] | direct_video;
   wire         video_rotated;
   wire         flip = 0;

//screen_rotate screen_rotate (.*);

   hps_io #(.CONF_STR(CONF_STR)) hps_io
     (
      .clk_sys(clk_sys),
      .HPS_BUS(HPS_BUS),
      .EXT_BUS(),
      .gamma_bus(),
      .direct_video ( direct_video ),
      .forced_scandoubler(forced_scandoubler),
      
      .buttons(buttons),
      .status(status),
      .status_menumask({status[5]}),
      
      .ps2_key(ps2_key),
      
      
      .ioctl_download(ioctl_download),
      .ioctl_wr(ioctl_wr),
      .ioctl_addr(ioctl_addr),
      .ioctl_dout(ioctl_dout),
      .ioctl_index(ioctl_index),
      
      .joystick_0(joystk1),
      .joystick_1(joystk2)      
      
        
        
      );
        
   arcade_video #(.WIDTH(256), .DW(12)) arcade_video
     (
      .*,
      .clk_video(CLK_48M),
      .ce_pix ( ce_pix ),
      .RGB_in( sfrgb ),//video),
      
      .HBlank(HBlank),
      .VBlank(VBlank),
      .HSync(~HSync),
      .VSync(~VSync),
      .fx(status[5:3]),
      .gamma_bus ()
      
      );
        
	// The rotation framebuffer shares the DDR port with the RetroAchievements
	// mirror (see RETROACHIEVEMENTS below), so its DDRAM outputs go through the RA mux.
	wire  [7:0] rot_burstcnt, rot_be;
	wire [28:0] rot_addr;
	wire [63:0] rot_din;
	wire        rot_we, rot_rd;

`ifdef MISTER_FB

	screen_rotate screen_rotate
	(
		.*,
		.video_rotated(),
		.rotate_ccw(0),
		.DDRAM_CLK(),
		.DDRAM_BURSTCNT(rot_burstcnt),
		.DDRAM_ADDR(rot_addr),
		.DDRAM_DIN(rot_din),
		.DDRAM_BE(rot_be),
		.DDRAM_WE(rot_we),
		.DDRAM_RD(rot_rd)
	);

`else
	
	assign {rot_burstcnt, rot_addr, rot_din, rot_be, rot_rd, rot_we} = '0;
	
`endif        
        
        
        
        

///////////////////////   CLOCKS   ///////////////////////////////

   wire clk_sys;
   wire CLK_48M;
   wire CLK_32M;
        
   pll pll
     (
      .refclk(CLK_50M),
      .rst(0),
      .outclk_0(clk_sys),
      .outclk_1(CLK_48M),
      .outclk_2(CLK_32M)
                
      );

   wire reset = RESET | status[0] | buttons[1];
   wire [1:0] col = status[4:3];
   wire       HBlank;
   wire       HSync;
   wire       VBlank;
   wire       VSync;
   wire	      ce_pix;
   wire [7:0] video = { r,g,b };
   wire [2:0] r,g;
   wire [1:0] b;
   wire [11:0] sfrgb;
   wire        clk_vid;
   wire        rom_download = ioctl_download && !ioctl_index;
   wire        iRST  = RESET | status[0] | buttons[1] | rom_download;
   wire        pressed = ps2_key[9];
   wire [8:0]  code    = ps2_key[8:0];

   always @(posedge clk_sys) begin
      reg old_state;
      old_state <= ps2_key[10];
      
      if(old_state != ps2_key[10]) begin
         casex(code)
           'hX75: btn_up          <= pressed; // up
           'hX72: btn_down        <= pressed; // down
           'hX6B: btn_left        <= pressed; // left
           'hX74: btn_right       <= pressed; // right
           'h014: btn_trig1       <= pressed; // ctrl
           'h005: btn_one_player  <= pressed; // F1
           'h006: btn_two_players <= pressed; // F2
           
           // JPAC/IPAC/MAME Style Codes
           'h016: btn_start_1     <= pressed; // 1
           'h01E: btn_start_2     <= pressed; // 2
           'h02E: btn_coin_1      <= pressed; // 5
         endcase
      end
   end

   reg btn_up    = 0;
   reg btn_down  = 0;
   reg btn_right = 0;
   reg btn_left  = 0;
   reg btn_trig1 = 0;
   reg btn_one_player  = 0;
   reg btn_two_players = 0;
   
   reg btn_start_1 = 0;
   reg btn_start_2 = 0;
   reg btn_coin_1  = 0;


   wire m_start1  = btn_one_player  | joystk1[5]  | joystk2[5]  | btn_start_1;
   wire m_start2  = btn_two_players | joystk1[8]  | joystk2[8]  | btn_start_2;

   wire m_up1     = btn_up      | joystk1[3] ;
   wire m_down1   = btn_down    | joystk1[2] ;
   wire m_left1   = btn_left    | joystk1[1] ;
   wire m_right1  = btn_right   | joystk1[0] ;
   wire m_trig11  = btn_trig1   | joystk1[4] ;

   wire m_coin1   = btn_one_player | btn_coin_1 | joystk1[6] | joystk2[6];
	
	wire m_pause   = joystk1[7] | joystk2[7];	
	
	reg pause_btn_prev = 0;
	reg pause_osd_prev = 0;
	reg pause_latch    = 0;

	always @(posedge clk_sys) begin
		if (iRST) begin
			pause_btn_prev <= 1'b0;
			pause_osd_prev <= status[8];
			pause_latch    <= status[8];
		end
		else begin
			pause_btn_prev <= m_pause;
			pause_osd_prev <= status[8];

			if (status[8] != pause_osd_prev)
				pause_latch <= status[8];
			else if (m_pause && !pause_btn_prev)
				pause_latch <= ~pause_latch;
		end
	end

   wire [6:0] UDLRTSC = { m_up1, m_down1, m_left1, m_right1, m_trig11, m_start1, m_coin1 };
   
   wire [15:0] Sout,SoutL,SoutR;

   //dipsw
   reg [7:0]   sw[8];
   always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;
   
   // RetroAchievements tap (see RETROACHIEVEMENTS below)
   wire [15:0] ra_cpu0_a, ra_cpu1_a;
   wire  [7:0] ra_cpu0_do, ra_cpu1_do;
   wire        ra_cpu0_we, ra_cpu1_we;

   NANO_STARFORC starforce
     (
      
      .reset ( iRST ),
      .clk_48m ( CLK_48M ),
      .clk_32m ( CLK_32M ),
      
      .pxclk ( ce_pix ),
      
      .HBlank ( HBlank ),
      .VBlank ( VBlank ),
      .HSync ( HSync ),
      .VSync ( VSync ),
      .red ( r ),
      .blue ( b ),
      .green ( g ),
      .sfrgb ( sfrgb ),
      
      .clk_sys ( clk_sys ),
      .ROMCL ( clk_sys ),
      .ROMAD ( ioctl_addr ),
      .ROMDT ( ioctl_dout ),
      .ROMEN ( ioctl_wr & rom_download ),
      
      .SOUT ( Sout ),
      //.SOUTL ( SoutL ),
      //.SOUTR ( SoutR ),
      
      
      .UDLRTSC ( UDLRTSC ),
      .dipsw ( { sw[0],sw[1]} ),
      .muteki ( status[6] ),

      .ra_cpu0_a  ( ra_cpu0_a  ),
      .ra_cpu0_do ( ra_cpu0_do ),
      .ra_cpu0_we ( ra_cpu0_we ),
      .ra_cpu1_a  ( ra_cpu1_a  ),
      .ra_cpu1_do ( ra_cpu1_do ),
      .ra_cpu1_we ( ra_cpu1_we )
      );

///////////////////   RETROACHIEVEMENTS   //////////////////
//
// RAM mirror for the RetroAchievements fork of Main_MiSTer
// (starforce_ra_mirror.v, from jotego's jtframe via the RA jtcores fork). RA
// arcade sets are written against FinalBurn Neo, whose Star Force driver
// (d_senjyo.cpp) exposes the MemIndex concatenation as "All Ram":
//     0x0000 DrvZ80RAM0  0x1000  main Z80 8000-8FFF
//     0x1000 DrvFgRAM    0x0800  main Z80 9000-97FF
//     0x1800 DrvSprRAM   0x0100  main Z80 9800-98FF
//     0x1900 DrvPalRAM   0x0200  main Z80 9C00-9DFF
//     0x1B00 DrvVidRegs  0x0100  main Z80 9E00-9EFF
//     0x1C00 DrvBgRAM0   0x0800  main Z80 B000-B7FF
//     0x2400 DrvBgRAM1   0x0800  main Z80 A800-AFFF
//     0x2C00 DrvBgRAM2   0x0800  main Z80 A000-A7FF
//     0x3400 DrvRadarRAM 0x0800  main Z80 B800-BBFF (0x3400-0x37FF)
//     0x3C00 DrvZ80RAM1  0x0400  sound Z80 4000-43FF
// The Z80s are 8-bit: shadow byte k is RA address k; the ARM region table is
// the identity {0, 0x4000, 0}.
//
// Both Z80s run on ripple clocks divided from CLK_32M (4 and 2 MHz), so the
// tap samples their buses on CLK_32M: a write cycle (MREQ+WR held for >= 12
// CLK_32M clocks) is only taken once two consecutive samples agree on
// strobe, address and data, and the older sample is written, so a sample
// caught while the bus changes is never used. The writes are decoded by CPU
// address, as FBNeo does.
//
// The only other DDR client is the screen rotation framebuffer, which runs on
// CLK_VIDEO (CLK_48M), ignores DDRAM_BUSY and writes one pixel per CE_PIXEL
// while VGA_DE is high. So the mirror is clocked by CLK_48M too (its shadow is
// written from CLK_32M through dual-clock BRAM, same PLL), and it only starts a
// copy once VGA_DE has been low for 4096 clocks (85 us, longer than any
// HBlank): the copy (2k qwords, ~50 us) then runs in VBlank and the
// framebuffer never loses a write. Held off during ROM download.

   function automatic [16:0] ra_map_main(input [15:0] a);  // {valid, offset}
      casez (a)
         16'b1000_????_????_????: ra_map_main = { 1'b1, 4'h0, a[11:0] };        // 8000 -> 0x0000
         16'b1001_0???_????_????: ra_map_main = { 1'b1, 5'b00010, a[10:0] };    // 9000 -> 0x1000
         16'b1001_1000_????_????: ra_map_main = { 1'b1, 8'h18, a[7:0] };        // 9800 -> 0x1800
         16'b1001_110?_????_????: ra_map_main = { 1'b1, 16'h1900 + {7'd0, a[8:0]} }; // 9C00 -> 0x1900
         16'b1001_1110_????_????: ra_map_main = { 1'b1, 8'h1B, a[7:0] };        // 9E00 -> 0x1B00
         16'b1011_0???_????_????: ra_map_main = { 1'b1, 16'h1C00 + {5'd0, a[10:0]} }; // B000 -> 0x1C00
         16'b1010_1???_????_????: ra_map_main = { 1'b1, 16'h2400 + {5'd0, a[10:0]} }; // A800 -> 0x2400
         16'b1010_0???_????_????: ra_map_main = { 1'b1, 16'h2C00 + {5'd0, a[10:0]} }; // A000 -> 0x2C00
         16'b1011_10??_????_????: ra_map_main = { 1'b1, 6'b001101, a[9:0] };    // B800 -> 0x3400
         default:                 ra_map_main = 17'd0;
      endcase
   endfunction

   reg        rm_we1, rm_we2, rs_we1, rs_we2;
   reg [15:0] rm_a1, rm_a2, rs_a1, rs_a2;
   reg  [7:0] rm_d1, rm_d2, rs_d1, rs_d2;
   always @(posedge CLK_32M) begin
      { rm_we1, rm_a1, rm_d1 } <= { ra_cpu0_we, ra_cpu0_a, ra_cpu0_do };
      { rm_we2, rm_a2, rm_d2 } <= { rm_we1, rm_a1, rm_d1 };
      { rs_we1, rs_a1, rs_d1 } <= { ra_cpu1_we, ra_cpu1_a, ra_cpu1_do };
      { rs_we2, rs_a2, rs_d2 } <= { rs_we1, rs_a1, rs_d1 };
   end

   wire [16:0] rm_map = ra_map_main(rm_a2);
   wire        rm_ok  = rm_we1 & rm_we2 & rm_a1 == rm_a2 & rm_d1 == rm_d2 & rm_map[16];
   wire        rs_ok  = rs_we1 & rs_we2 & rs_a1 == rs_a2 & rs_d1 == rs_d2 & rs_a2[15:10] == 6'b010000;

   wire [14:0] ra_wr_word;
   wire [15:0] ra_wr_din;
   wire  [1:0] ra_wr_be;

   starforce_ra_tap_merge #(.N(2)) ra_tap
     (
      .clk(CLK_32M),
      .we({ rs_ok, rm_ok }),
      .off({ 16'h3C00 + { 6'd0, rs_a2[9:0] }, rm_map[15:0] }),
      .din({ rs_d2, rm_d2 }),
      .ra_wr_word(ra_wr_word),
      .ra_wr_din(ra_wr_din),
      .ra_wr_be(ra_wr_be)
      );

   reg [1:0] ra_rst_s, ra_vbl_s, ra_dl_s;
   always @(posedge CLK_48M) begin
      ra_rst_s <= { ra_rst_s[0], iRST };
      ra_vbl_s <= { ra_vbl_s[0], VBlank };
      ra_dl_s  <= { ra_dl_s[0],  ioctl_download };
   end

   reg [11:0] ra_de_idle;
   always @(posedge CLK_48M) begin
      if (VGA_DE) ra_de_idle <= 0;
      else if (~&ra_de_idle) ra_de_idle <= ra_de_idle + 1'd1;
   end

   wire  [7:0] ra_burstcnt, ra_be;
   wire [28:0] ra_addr;
   wire [63:0] ra_din;
   wire        ra_we, ra_active;

   starforce_ra_mirror #(.AW(14)) ra_mirror
     (
      .rst(ra_rst_s[1]),
      .clk(CLK_48M),
      .lvbl(~ra_vbl_s[1]),
      .hold(ra_dl_s[1]),
      .start_ok(&ra_de_idle),
      .wr_clk(CLK_32M),
      .wr_word(ra_wr_word),
      .wr_din(ra_wr_din),
      .wr_be(ra_wr_be),
      .active(ra_active),
      .ddr_busy(DDRAM_BUSY),
      .ddr_burstcnt(ra_burstcnt),
      .ddr_addr(ra_addr),
      .ddr_we(ra_we),
      .ddr_be(ra_be),
      .ddr_din(ra_din)
      );

   assign DDRAM_CLK      = CLK_48M;
   assign DDRAM_BURSTCNT = ra_active ? ra_burstcnt : rot_burstcnt;
   assign DDRAM_ADDR     = ra_active ? ra_addr     : rot_addr;
   assign DDRAM_DIN      = ra_active ? ra_din      : rot_din;
   assign DDRAM_BE       = ra_active ? ra_be       : rot_be;
   assign DDRAM_WE       = ra_active ? ra_we       : rot_we;
   assign DDRAM_RD       = ra_active ? 1'b0        : rot_rd;

endmodule
