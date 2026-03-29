module AXI_4_lite_slave_core (

  // GLOBAL SIGNALS
  input         ACLK,
  input         ARESETN,

  // WRITE ADDRESS (AW) CHANNEL
  input   [31:0]        AWADDR,
  input                 AWVALID,
  output                AWREADY,
  output  [31:0]        slave_wr_addr,

  // WRITE DATA (W) CHANNEL
  input   [31:0]       WDATA,
  input                WVALID,
  output               WREADY,
  output  [31:0]       slave_w_data,


  // WRITE RESPONSE (B) CHANNEL
  input              BREADY,
  output             BVALID,
  output             BRESP,

  // READ ADDRESS (AR) CHANNEL
  input             ARVALID,
  input   [31:0]    ARADDR,
  output            ARREADY,
  output  [31:0]    slave_ar_addr,

  // READ DATA (R) CHANNEL
  input            RREADY,
  input   [31:0]    slave_r_data,
  output  [31:0]    RDATA,
  output            RVALID,
  output            RRESP

);

//--------------------------------
// INTERNAL SIGNALS
//--------------------------------
// handshake write transaction done flag to enable response valid (b channel)
wire b_enable;

// hand shake read transaction done flags to control arready and rvalid
wire ar_transfer_done;
wire r_transfer_done;


//--------------------------------
// AW && W CHANNEL INSTANTIATION
//--------------------------------
AXI_Write_channel AW_and_W_channel(
.clk(ACLK),
.rst_n(ARESETN),
.write_trans_done(b_enable),

.aw_ready(AWREADY),
.aw_valid(AWVALID),
.aw_addr(AWADDR),
.slave_wr_addr(slave_wr_addr),

.w_ready(WREADY),
.w_valid(WVALID),
.w_data(WDATA),
.slave_w_data(slave_w_data)
);

//--------------------------------
// B CHANNEL INSTANTIATION
//--------------------------------
AXI_B_channel B_channel(
.clk(ACLK),
.rst_n(ARESETN),
.b_ready(BREADY),
.enable(b_enable),
.b_valid(BVALID),
.b_resp(BRESP)
);


//--------------------------------
// AR CHANNEL INSTANTIATION
//--------------------------------
AXI_AR_channel AR_channel (
.clk(ACLK),
.rst_n(ARESETN),
.ar_valid(ARVALID),
.ar_addr(ARADDR),
.ar_ready(ARREADY),
.slave_ar_addr(slave_ar_addr),
.ar_transfer_done(ar_transfer_done),
.r_transfer_done(r_transfer_done)
);

//--------------------------------
// R CHANNEL INSTANTIATION
//--------------------------------
AXI_R_channel R_channel (
.clk(ACLK),
.rst_n(ARESETN),
.r_ready(RREADY),
.r_valid(RVALID),
.r_data(RDATA),
.r_resp(RRESP),
.slave_r_data(slave_r_data),
.r_transfer_done(r_transfer_done),
.ar_transfer_done(ar_transfer_done)
);

endmodule



