module AXI_AR_channel(

  input                     clk,
  input                     rst_n,


  input                     ar_valid,
  input       [31:0]        ar_addr,

  output  reg               ar_ready,
  output  reg [31:0]        slave_ar_addr,

  //CONTROL FLAGS
  input                     r_transfer_done,
  output  reg               ar_transfer_done
);

  //------------------------------------------
  // ADDRESS SAMPLING
  //------------------------------------------
  always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      slave_ar_addr <= 32'b0;
    end

    // Sample the address when both ar_valid and ar_ready are high, and ar_transfer_done is not already asserted.
    // This ensures that the address is only sampled once per read transaction.
    else if(ar_valid && ar_ready && !ar_transfer_done) begin
      slave_ar_addr <= ar_addr;
    end

  end

  //------------------------------------------
  // READY LOGIC
  //------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_ready <= 1'b1;
    end

    // 1) Once ar_transfer_done is asserted, the slave should not accept new addresses until the current read transaction is completed
    //    Which is indicated by r_transfer_done.
    // 2) Now also, you can do new read transaction back to back just after previous transaction is done
    //    without waiting for one extra cycle because ar_ready is deasserted only when ar_transfer_done is asserted
    //    and it will be reasserted as soon as r_transfer_done is asserted indicating that the previous transaction is done and slave can accept new address.
    else if (ar_transfer_done && !r_transfer_done) begin
      ar_ready <= 1'b0;
    end

    else begin
      ar_ready <= 1'b1;
    end

  end

  //------------------------------------------
  // AR CHANNEL TRANSFER DONE FLAG LOGIC
  //------------------------------------------

    always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_transfer_done <= 1'b0;
    end

    else if (ar_valid && ar_ready) begin
      ar_transfer_done <= 1'b1;
    end

    else if(r_transfer_done) begin
      ar_transfer_done <= 1'b0;
    end

  end

endmodule

