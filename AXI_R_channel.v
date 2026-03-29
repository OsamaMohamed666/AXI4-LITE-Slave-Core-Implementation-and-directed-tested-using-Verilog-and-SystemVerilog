module AXI_R_channel (

  input               clk,
  input               rst_n,

  //CONTROL FLAGS
  input               ar_transfer_done,
  output  reg         r_transfer_done,

  input               r_ready,
  input   [31:0]      slave_r_data,

  output  reg          r_resp,
  output  reg          r_valid,
  output  reg [31:0]   r_data
);

  //RESPONSE VALUES
  localparam  SLVERR = 1'b1,
              OKAY = 1'b0;

  //------------------------------------------
  // READ DATA AND RESPONSE LOGIC
  //------------------------------------------
  always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      r_data <= 32'b0;
      r_resp <= 1'b0;
    end

    // Once valid is asserted, the data and control signals must remain unchanged until r_ready is asserted.
    // Therefore, adding !r_valid ensures that the same data is not sampled multiple times
    else if (ar_transfer_done && !r_valid && !r_transfer_done) begin
      r_data <= slave_r_data;
      r_resp <= OKAY;
    end

  end

  //------------------------------------------
  // RVALID LOGIC
  //------------------------------------------
  always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      r_valid <= 1'b0;
    end

    // assert r_valid only when ar_transfer_done is asserted and r_valid is not already asserted and r_transfer_done is not already asserted.
    // This ensures that r_valid is asserted only once per read transaction.
    else if (ar_transfer_done && !r_valid && !r_transfer_done) begin
      r_valid <= 1'b1;
    end

    else if (r_ready && r_valid) begin // wait till handshake between master and slave is done
      r_valid <= 1'b0;
    end

  end

  //------------------------------------------
  // R CHANNEL TRANSFER DONE FLAG LOGIC
  //------------------------------------------

  always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      r_transfer_done <= 1'b0;
    end

    // Generating a pulse to indicate that the transaction is complete.
    else if (r_ready && r_valid) begin
      r_transfer_done <= 1'b1;
    end

    else begin
      r_transfer_done <= 1'b0;
    end

  end

endmodule
