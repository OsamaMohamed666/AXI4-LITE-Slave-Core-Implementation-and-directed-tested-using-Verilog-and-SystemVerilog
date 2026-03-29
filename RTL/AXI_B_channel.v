module AXI_B_channel (

  input           clk,
  input           rst_n,

  input           b_ready,
  input           enable,

  output  reg     b_resp,
  output  reg     b_valid
);

localparam  SLVERR = 1'b1,
            OKAY = 1'b0;

always @ (posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    b_resp  <= 1'b0;
    b_valid <= 1'b0;
  end

  else if (enable && b_ready)
    begin
      b_valid <= 1'b1;
      b_resp  <= OKAY;
    end

  else if (b_ready) // handshake now completed now deassert b_valid
    b_valid <= 1'b0;

end


endmodule
